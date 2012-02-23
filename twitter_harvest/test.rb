require 'rubygems'
require 'twitter/json_stream'
require 'yaml'
require 'mysql2/em'


config = YAML.load_file("settings.yaml")
@username = config["username"]
@password = config["password"]

puts "Prepping the event machine. Start your engines....."

dc_bounding = "locations=-77.17,38.84,-76.90,39"
#dc_bounding = "locations=-122.75,36.8,-121.75,37.8,-74,40,-73,41"




EventMachine::run {
  stream = Twitter::JSONStream.connect(
    :ssl => true,
    :path    => '/1/statuses/filter.json?' + dc_bounding,
    :auth    => @username + ":" + @password
  )

  stream.each_item do |item|
	puts item
	client1 = Mysql2::EM::Client.new(:host => "localhost", :database => "search_local", :username => "root")
	defer1 = client1.query "insert into tweets(tweet) values('" + item.to_s.gsub('"', '\"') +"')"
  defer1.callback do |result|
    puts "Result: #{result.to_a.inspect}"
  end
	#client1.query "insert into tweets(tweet) values(" + item + ")"
	#client1.query "insert into tweets(tweet) values('testter')"
  end

  stream.on_error do |message|
    # No need to worry here. It might be an issue with Twitter. 
    # Log message for future reference. JSONStream will try to reconnect after a timeout.
  end

  stream.on_max_reconnects do |timeout, retries|
    # Something is wrong on your side. Send yourself an email.
  end
}
