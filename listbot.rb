# frozen_string_literal: true

require 'skyfall'
require 'minisky'
require 'net/http'
require 'openssl'
require 'json'
require 'time'
require 'eventmachine'
require 'celluloid'
require 'celluloid/autostart'
require 'celluloid/pool'

# EDIT THIS SECTION

# this should be the hostname you have deployed ozone to
$OZONE_HOSTNAME = "ozone.service.tld"

# this is a hashmap that maps your labels to your lists
# add your labels and lists using the following format
# 'label' => 'list id'
$label_to_list = {
'antisemitism' => '3kbqy62rg542l',
}
# DO NOT EDIT BELOW HERE

@last_update = Time.new
$bsky = Minisky.new('bsky.social', 'creds.yml')

class MessageProcessing
  include Celluloid

  def process_create_message(m, seq)
    m.labels.each do |label|
      if (/^did:[webplc]{3}:[a-z0-9]+$/i =~ label.data['uri'])
        puts "#{label.data['uri']}, #{label.data['val']}, #{label.data['neg'] || false}"
        repo = label.data['uri']
        list = $label_to_list[label.data['val']]
        if label.data['neg'] == true
          remove_from_list(repo, list)
        else
          add_to_list(repo, list)
        end
      end
    end
  end
end

def remove_from_list(repo, list)
  # TODO
  puts "remove #{repo} from #{list}"
  entries = $bsky.fetch_all('app.bsky.graph.getList',
  { list: "at://#{$bsky.user.did}/app.bsky.graph.list/#{list}" },
  field: 'items')
  entries.each do |entry|
    if entry['subject']['did'] == repo
      uri = URI.parse("https://bsky.social/xrpc/com.atproto.repo.deleteRecord")

      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "Bearer #{$bsky.config['access_token']}"
      request.body = JSON.dump({
        "repo" => "#{$bsky.user.did}",
        "collection" => 'app.bsky.graph.listitem',
        "rkey" => entry['uri'].split('/')[-1]
      })
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      puts response.body
      break
    end
  end
end

def add_to_list(repo, list)
  # TODO
  puts "add #{repo} to #{list}"
  $bsky.post_request('com.atproto.repo.createRecord', {
                     repo: "#{$bsky.user.did}",
                     collection: 'app.bsky.graph.listitem',
                     record: {
                       subject: "#{repo}",
                       list: "at://#{$bsky.user.did}/app.bsky.graph.list/#{list}",
                       createdAt: Time.now.iso8601
                     }
                   })
end

message_worker_pool = MessageProcessing.pool(size: 200)

connected = false

sky = Skyfall::Stream.new($OZONE_HOSTNAME, :subscribe_labels)
sky.on_connect do
  puts 'Connected to ozone'
  connected = true
  @last_update = Time.now

  @timer ||= EM.add_periodic_timer(20) do
    diff = Time.now - @last_update
    if diff > 30
      @sky.instance_variable_get('@ws')&.ping('hey')
    end
  end
end

sky.on_disconnect do
  puts 'Disconnected from bluesky'
  connected = false
end

sky.on_error do |error|
  puts error
end

sky.on_message do |m|
  @last_update = Time.now
  message_worker_pool.process_create_message(m, sky.cursor)
end

sky.connect

begin
  loop { sleep 1 if connected }
rescue SignalException
  connected = false
  sky.disconnect
  puts 'Exiting'
  exit 0
end
