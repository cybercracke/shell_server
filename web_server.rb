
require 'json'
require 'sinatra/base'
require 'sinatra-websocket'

class ShellClient
  attr_reader :ip, :web_socket

  def initialize(web_socket)
    @web_socket = web_socket
    @ip = Addrinfo.new(web_socket.get_peername).ip_unpack
  end

  def send(msg)
    web_socket.send(msg)
  end
end

class App < Sinatra::Base
  disable :protection
  enable :logging, :inline_templates

  set :root, File.expand_path(File.dirname(__FILE__))
  set :shell_clients, []

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
        logger.info("Websocket opened from #{sc.ip.join(':')}")

        sc.send(JSON.generate(get_shell_servers))
        settings.shell_clients << sc
      end

      ws.onmessage do |msg|
        EM.next_tick { settings.shell_clients.each{ |s| s.send(msg) } }
      end

      ws.onclose do
        sc = settings.shell_clients.select { |s| s.web_socket == ws }.first
        logger.info("Websocket closed from #{sc.ip.join(':')}")
        settings.shell_clients.delete_if { |s| s.web_socket == ws }
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
        'type' => 'server_list',
        'servers' => [
          {'name' => 'test1', 'shells' => ['asdf', 'quiten']},
          {'name' => 'test2', 'shells' => []}
        ],
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
<div class="shells">
</div>

<script type="text/javascript">
  window.onload = function(){
    (function() {
      var ws       = new WebSocket('ws://' + window.location.host + '/sockets');

      ws.onopen    = function()  { console.log('Websocket opened'); };
      ws.onclose   = function()  { console.log('Websocket closed'); }
      ws.onmessage = function(m) { console.log(m); };
    })();
  }
</script>
