
require 'json'
require 'securerandom'

require 'redis'
require 'hiredis'
require 'sinatra/base'
require 'sinatra-websocket'

JSON.create_id = nil

module MessageHandler
  def process(message, clients, source)
    message = JSON.parse(message)

    if message.has_key?('dest')
      dest = clients.select { |sc| sc.id == message['dest'] }.first
      return if dest.nil?
      dest.publish(message['type'], message['data'], source.id)
    else
      clients.each do |sc|
        sc.publish(message['type'], message['data'], source.id)
      end
    end
  end

  module_function :process
end

class ShellClient
  attr_reader :id, :ip, :web_socket

  def initialize(web_socket)
    @id = SecureRandom.uuid
    @web_socket = web_socket
    @subscriptions = []
    @ip = '[%s]:%s' % Addrinfo.new(web_socket.get_peername).ip_unpack
  end

  def publish(channel, message, source)
    # Don't send messages sent from this client back to its self.
    #return if source == id

    message_type = channel.split(':')[1..-1]
    web_socket.send(JSON.generate({'type' => channel, 'data' => message, 'source' => source}))
  end

  def send(msg)
    web_socket.send(msg)
  end
end

class App < Sinatra::Base
  disable :protection
  enable :logging, :inline_templates

  set :root, File.expand_path(File.dirname(__FILE__))

  # This is the handler for communicating back and forth between websockets and
  # redis. Most of the logic around the communications is handled by the
  # ShellClient publisher.
  set(:publisher, Thread.new do
    Thread.current['shell_clients'] = []

    logger = Logger.new('logs/publisher.log')
    logger.info("Spawing publisher thread")

    redis = Redis.new(driver: :hiredis)
    redis.psubscribe('shells:*') do |on|
      on.message do |channel, message|
        logger.warn(sprintf("[%s]: %s\n", channel, message))

        Thread.current['shell_clients'].each do |sc|
          sc.publish(channel, message)
        end
      end
    end
  end)

  set :redis, Redis.new(driver: :hiredis)

  configure :development do
    enable :raise_errors
    enable :show_exceptions
  end

  get '/' do
    erb :index
  end

  get '/sockets' do
    pass unless request.websocket?

    request.websocket do |ws|
      ws.onopen do
        sc = ShellClient.new(ws)
        sc.send(JSON.generate(get_shell_servers))
        logger.info("Websocket opened from #{sc.ip}")

        settings.publisher['shell_clients'] << sc
      end

      ws.onmessage do |msg|
        message = JSON.parse(msg)

        source = settings.publisher['shell_clients'].select { |sc| sc.web_socket == ws }.first
        message['source'] = source.id

        channel = "shells:#{message['type']}"

        EM.next_tick { settings.redis.publish(channel, JSON.generate(message)) }
      end

      ws.onclose do
        sc = settings.publisher['shell_clients'].select { |s| s.web_socket == ws }.first
        logger.info("Websocket closed from #{sc.ip}")
        settings.publisher['shell_clients'].delete(sc)
      end
    end
  end

  not_found do
    erb "WHHHAAAATTT, This page doesn't exist"
  end

  error do
    erb "Oh the humanity! An error occurred"
  end

  helpers do
    # TODO: Get shells from redis instance and send to populate the client's
    # browser.
    def get_shell_servers
      {
        'type' => 'shells:servers',
        'data' => {
          'servers' => [
            {'name' => 'test1', 'shell_keys' => ['asdf', 'quiten'], 'uuid' => SecureRandom.uuid},
            {'name' => 'test2', 'shell_keys' => [], 'uuid' => SecureRandom.uuid}
          ]
        }
      }
    end
  end
end

__END__

@@ layout
<!DOCTYPE>
<html>
  <head>
    <title>Testing Shell Server</title>
    <style>
      *, *:after, *:before {
        -webkit-box-size: border-box;
        -moz-box-sizing:  border-box;
        box-sizing:       border-box;
      }

      body {
        line-height: 1.4em;
        font-size: 1.1em;
      }
    </style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>

@@ index
<div id="shell_servers">
</div>
<div id="shells">
  <div id="uuid:astkjf"><p>Something 1</p></div>
  <div id="uuid:aldkjf"><p>Something 2</p></div>
  <div id="uuid:asdkjf"><p>Something 3</p></div>
  <div id="uuid:aslkjf"><p>Something 4</p></div>
</div>

<script type="text/javascript" src='/app.js'></script>
