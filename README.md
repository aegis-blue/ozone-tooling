# Aegis Ozone Tools

These are tools used by the aegis moderation team. We are opensourcing them to allow other labeler service to use them as well should they wish.

`events_worker.rb` - reads the events list from ozone and posts them to a discord webhook

`listbot.rb` - reads labels as they occur on the ozone firehose. If the target of a label is an account, it adds the account to a provided listid automatically. The script also handles removing users from lists if the label is removed from the account.

## Installing/Using
1. clone the repo to your server
`git clone https://github.com/aetaric/aegis_ozone-tools.git`
2. install required deps
Ubuntu:
`sudo apt install -y build-essential ruby-dev ruby openssl libssl-dev`
3. install bundler
`gem install bundler`
4. install script requirements
`bundle install`
5. edit creds.yml to have your bsky labeler user and pass
6. edit the script you wish to use. only edit the section between `EDIT THIS SECTION` and `DO NOT EDIT BELOW HERE`
