
require 'json'
require 'securerandom'

require 'redis'
require 'hiredis'
require 'sinatra/base'
require 'sinatra-websocket'

JSON.create_id = nil
WS_UUID = SecureRandom.uuid

Thread.current[:redis] = Redis.new(driver: :hiredis)

module MessageHandler
  def logger
    @@logger ||= Logger.new('logs/publisher.log')
  end

  def process(raw_message)
    logger.info(raw_message)
    msg = JSON.parse(raw_message)

    Thread.current[:shell_clients].each do |sc|
      case msg['ty']
      when 'servers:new', 'servers:removed'
        sc.send_shell_servers
      else
        # Don't echo our messages back to ourselves, and only send messages to
        # their intended destination if a destination is provided.
        if msg['so'] != sc.id && (!msg.has_key?('de') || msg['de'] == sc.id)
          sc.send(raw_message)
        end
      end
    end
  rescue => e
    logger.error("MessageHandler broke because: #{e.message}")
  end

  module_function :logger, :process
end

class ShellClient
  attr_reader :id, :ip, :web_socket

  def initialize(web_socket)
    @id = SecureRandom.uuid
    @web_socket = web_socket
    @subscriptions = []
    @ip = '[%s]:%s' % Addrinfo.new(web_socket.get_peername).ip_unpack

    send_shell_servers
  end

  def send(msg)
    msg = JSON.parse(msg) if msg.is_a?(String)
    web_socket.send(JSON.generate(msg))
  end

  def send_shell_servers
    puts "Sending new server list"
    servers = Thread.current[:redis].smembers('shells:servers')
    raise "No servers error" if servers.nil? || servers.empty?
    servers.map! do |s|
      JSON.parse(s)
    end
    send({ 'ty' => 'servers', 'da' => servers, 'de' => id, 'so' => WS_UUID })
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
    Thread.current[:shell_clients] = []
    Thread.current[:redis] = Redis.new(driver: :hiredis)
    Thread.current[:redis].subscribe('shells') do |on|
      on.message do |_, message|
        MessageHandler.process(message)
      end
    end
  end)

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
        logger.info("Websocket opened from #{sc.ip}")
        settings.publisher[:shell_clients] << sc
      end

      ws.onmessage do |msg|
        message = JSON.parse(msg)

        source = settings.publisher[:shell_clients].select { |sc| sc.web_socket == ws }.first
        message['so'] = source.id

        EM.next_tick { Thread.current[:redis].publish('shells', JSON.generate(message)) }
      end

      ws.onclose do
        sc = settings.publisher[:shell_clients].select { |s| s.web_socket == ws }.first
        logger.info("Websocket closed from #{sc.ip}")
        settings.publisher[:shell_clients].delete(sc)
      end
    end
  end

  not_found do
    erb "WHHHAAAATTT, This page doesn't exist"
  end

  error do
    erb "Oh the humanity! An error occurred"
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

      .shell {
        font-family: monospace;
        line-height: 1.0em;
      }

      .hidden.shell {
        display: none;
      }

      .current.shell {
        display: block;
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
</div>

<script type="text/javascript" src='/app.js'></script>
<script type="text/javascript" src='/term.js'></script>
