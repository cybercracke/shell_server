
require 'json'
require 'sinatra/base'
require 'sinatra-websocket'

class ShellClient
  attr_reader :web_socket

  def initialize(web_socket)
    @web_socket = web_socket
  end
end

class App < Sinatra::Base
  disable :protection
  enable :logging

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
        logger.info("Websocket opened from #{ws.request.to_h}")
        settings.shell_clients << ShellClient.new(ws)
      end

      ws.onmessage do |msg|
        EM.next_tick { settings.shell_clients.each{ |s| s.web_socket.send(msg) } }
      end

      ws.onclose do
        logger.info("Websocket closed from #{ws.request["host"]}")
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

  template :index do
    <<-'EOI'
<form id="form"><input type="text" id="input"/></form>

<script type="text/javascript">
  window.onload = function(){
    (function() {
      var ws       = new WebSocket('ws://' + window.location.host + '/sockets');

      ws.onopen    = function()  { console.log('Websocket opened'); };
      ws.onclose   = function()  { console.log('Websocket closed'); }
      ws.onmessage = function(m) { console.log(m); };

      var sender = function(f) {
        var input  = document.getElementById('input');

        f.onsubmit = function(event) {
          event.preventDefault();
          ws.send(input.value);
          input.value = "";
        }
      }(document.getElementById('form'));

      window.ws = ws;
    })();
  }
</script>
    EOI
  end

  template :layout do
    <<-'EOL'
<!DOCTYPE>
<html>
  <head>
    <title>Testing Shell Server</title>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
    EOL
  end
end

