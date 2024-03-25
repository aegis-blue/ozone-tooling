require 'minisky'
require 'json'
require 'discordrb/webhooks'

puts "Starting events listener"

$PDS_URL = "porcini.us-east.host.bsky.network"
$LABELER_DID = "did:plc:j67mwmangcbxch7knfm7jo2b"
WEBHOOK_URL = "https://discord.com/api/webhooks/"

# we need to get a bearer token
$bsky = Minisky.new('bsky.social', 'creds.yml')

# setup discord webhook
$webhook = Discordrb::Webhooks::Client.new(url: WEBHOOK_URL)

# file to track the state of the worker
if File.exist? 'cursor'
  cursor_file = File.open('cursor','r')
  $cursor = cursor_file.read
else
  $cursor = nil
end

# login if needed
$bsky.log_in

def fetch_events()
  uri = URI.parse("https://#{PDS_URL}/xrpc/tools.ozone.moderation.queryEvents?limit=25")
  request = Net::HTTP::Get.new(uri)
  request["Authority"] = "#{PDS_URL}"
  request["Atproto-Accept-Labelers"] = "did:plc:ar7c4by46qjdydhdevvrndac;redact"
  request["Atproto-Proxy"] = "#{$LABELER_DID}#atproto_labeler"
  request["Authorization"] = "Bearer #{$bsky.config['access_token']}"
  
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  
  if response.code.to_i == 200
    data = JSON.load(response.body)
    events = data['events'].reverse 
    events.each do |event|
      if event["id"] <= $cursor.to_i
        next
      end
      $webhook.execute do |builder|
        case event["event"]["$type"]
        when "tools.ozone.moderation.defs#modEventAcknowledge"
          builder.add_embed do |embed|
            embed.title = "Acknowledge"
            embed.description = "Acknowledge ##{event["id"]}"
            embed.timestamp = Time.parse(event["createdAt"])
            embed.colour = 0x7ed321
            embed.add_field(name: "Mod Handle", value: "#{event["creatorHandle"]}")
            case event["subject"]["$type"]
            when "com.atproto.repo.strongRef" # post
              embed.add_field(name: "Record", value: "#{event["subject"]["uri"]}")
            when "com.atproto.admin.defs#repoRef" # account
              embed.add_field(name: "DID", value: "#{event["subject"]["did"]}")
            end
            embed.add_field(name: "Target Handle", value: "#{event["subjectHandle"]}")
            embed.add_field(name: "Comment", value: "#{event["event"]["comment"]}")
          end
        when "tools.ozone.moderation.defs#modEventReport"
          builder.add_embed do |embed|
            embed.title = "New Report"
            embed.description = "Report ##{event["id"]}"
            embed.timestamp = Time.parse(event["createdAt"])
            embed.colour = 0xf5a623
            embed.add_field(name: "Report Type", value: "#{event["event"]["reportType"].split("#")[1]}")
            case event["subject"]["$type"]
            when "com.atproto.repo.strongRef" # post
              embed.add_field(name: "Record", value: "#{event["subject"]["uri"]}")
            when "com.atproto.admin.defs#repoRef" # account
              embed.add_field(name: "DID", value: "#{event["subject"]["did"]}")
            end
            embed.add_field(name: "Target Handle", value: "#{event["subjectHandle"]}")
            embed.add_field(name: "Reporter Handle", value: "#{event["creatorHandle"]}")
            embed.add_field(name: "Comment", value: "#{event["event"]["comment"]}")
          end
        when "tools.ozone.moderation.defs#modEventLabel"
          builder.add_embed do |embed|
            embed.title = "Label Update"
            embed.description = "Updated Labels: ##{event["id"]}"
            embed.timestamp = Time.parse(event["createdAt"])
            embed.colour = 0x7ed321
            case event["subject"]["$type"]
            when "com.atproto.repo.strongRef" # post
              embed.add_field(name: "Record", value: "#{event["subject"]["uri"]}")
            when "com.atproto.admin.defs#repoRef" # account
              embed.add_field(name: "DID", value: "#{event["subject"]["did"]}")
            end
            embed.add_field(name: "Target Handle", value: "#{event["subjectHandle"]}")
            embed.add_field(name: "Mod Handle", value: "#{event["creatorHandle"]}")
            embed.add_field(name: "Labels Added", value: "#{event["event"]["createLabelVals"].join(", ")}")
            embed.add_field(name: "Labels Removed", value: "#{event["event"]["negateLabelVals"].join(", ")}")
            embed.add_field(name: "Comment", value: "#{event["event"]["comment"]}")
          end
        when "tools.ozone.moderation.defs#modEventTag"
          builder.add_embed do |embed|
            embed.title = "Tag Update"
            embed.description = "Updated Tags: ##{event["id"]}"
            embed.timestamp = Time.parse(event["createdAt"])
            embed.colour = 0x4a90e2
            case event["subject"]["$type"]
            when "com.atproto.repo.strongRef" # post
              embed.add_field(name: "Record", value: "#{event["subject"]["uri"]}")
            when "com.atproto.admin.defs#repoRef" # account
              embed.add_field(name: "DID", value: "#{event["subject"]["did"]}")
            end
            embed.add_field(name: "Target Handle", value: "#{event["subjectHandle"]}")
            embed.add_field(name: "Mod Handle", value: "#{event["creatorHandle"]}")
            embed.add_field(name: "Tags Added", value: "#{event["event"]["add"].join(", ")}")
            embed.add_field(name: "Tags Removed", value: "#{event["event"]["remove"].join(", ")}")
            embed.add_field(name: "Comment", value: "#{event["event"]["comment"]}")
          end
        when "tools.ozone.moderation.defs#modEventComment"
          builder.add_embed do |embed|
            embed.title = "Comment"
            embed.description = "Mod Comment: ##{event["id"]}"
            embed.timestamp = Time.parse(event["createdAt"])
            embed.colour = 0x4a90e2
            case event["subject"]["$type"]
            when "com.atproto.repo.strongRef" # post
              embed.add_field(name: "Record", value: "#{event["subject"]["uri"]}")
            when "com.atproto.admin.defs#repoRef" # account
              embed.add_field(name: "DID", value: "#{event["subject"]["did"]}")
            end
            embed.add_field(name: "Target Handle", value: "#{event["subjectHandle"]}")
            embed.add_field(name: "Mod Handle", value: "#{event["creatorHandle"]}")
            embed.add_field(name: "Comment", value: "#{event["event"]["comment"]}")
          end
        when "tools.ozone.moderation.defs#modEventEscalate"
          builder.add_embed do |embed|
            embed.title = "Escalation"
            embed.description = "Escalation: ##{event["id"]}"
            embed.timestamp = Time.parse(event["createdAt"])
            embed.colour = 0xd0021b
            case event["subject"]["$type"]
            when "com.atproto.repo.strongRef" # post
              embed.add_field(name: "Record", value: "#{event["subject"]["uri"]}")
            when "com.atproto.admin.defs#repoRef" # account
              embed.add_field(name: "DID", value: "#{event["subject"]["did"]}")
            end
            embed.add_field(name: "Target Handle", value: "#{event["subjectHandle"]}")
            embed.add_field(name: "Mod Handle", value: "#{event["creatorHandle"]}")
            embed.add_field(name: "Comment", value: "#{event["event"]["comment"]}")
          end
        else
          puts "unknown event #{event['event']['$type']}"
        end
      end
      $cursor = event["id"]
      sleep(2)
    end
  else
    puts "Failed to fetch events: #{response.body}"
  end
end

def write_cursor(cursor)
  cursor_file = File.open('cursor','w')
  cursor_file.write(cursor)
  cursor_file.flush
  cursor_file.close
end

while true do
  fetch_events
  write_cursor($cursor)
  sleep(30) # hacky, but we'll sleep for 5 seconds between runs
end
