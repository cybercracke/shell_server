
require 'json'

require 'redis'
require 'hiredis'
require 'sinatra/base'
require 'sinatra-websocket'

class ShellClient
  attr_reader :ip, :web_socket

  def initialize(web_socket)
    @web_socket = web_socket
    @ip = Addrinfo.new(web_socket.get_peername).ip_unpack
  end

  def publish(channel, message)
    puts "#{channel}: #{message}"
    web_socket.send(JSON.generate({'type' => channel, 'data' => message}))
  end

  def send(msg)
    web_socket.send(msg)
  end
end

class App < Sinatra::Base
  disable :protection
  enable :logging, :inline_templates

  set :root, File.expand_path(File.dirname(__FILE__))
  set(:publisher, Thread.new do
    redis = Redis.new
    Thread.current['shell_clients'] = []

    redis.subscribe('shells:*') do |on|
      on.message do |channel, message|
        Thread.current['shell_clients'].each do |sc|
          sc.publish(channel, message)
        end
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
        sc.send(JSON.generate(get_shell_servers))
        logger.info("Websocket opened from #{sc.ip.join(':')}")

        settings.publisher['shell_clients'] << sc
      end

      ws.onmessage do |msg|
        EM.next_tick { settings.publisher['shell_clients'].each{ |sc| s.send(msg) } }
      end

      ws.onclose do
        sc = settings.shell_clients.select { |s| s.web_socket == ws }.first
        logger.info("Websocket closed from #{sc.ip.join(':')}")
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
        'type' => 'server_list',
        'servers' => [
          {'name' => 'test1', 'shell_keys' => ['asdf', 'quiten'], 'uuid' => SecureRandom.uuid},
          {'name' => 'test2', 'shell_keys' => [], 'uuid' => SecureRandom.uuid}
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
<div id="shells">
  <div id="uuid:asldkjf"><p>Something 1</p></div>
  <div id="uuid:aldkjf"><p>Something 2</p></div>
  <div id="uuid:asdkjf"><p>Something 3</p></div>
  <div id="uuid:aslkjf"><p>Something 4</p></div>
</div>

<script type="text/javascript">
  // Global for holding the current list of known servers and shells.
  window.servers = {};

  // Anytime the server list gets updated we'll need to redraw the list. This
  // function handles it.
  var drawServers = function() {
    newServerList = document.createElement('ul');

    for (uuid in window.servers) {
      serverLi = document.createElement('li');
      serverLi.innerText = window.servers[uuid]['name'];
      serverLi.setAttribute('data-uuid', uuid);

      newShellList = document.createElement('ul');

      for (i in window.servers[uuid]['shell_keys']) {
        shellLi = document.createElement('li');
        shellLi.innerText = window.servers[uuid]['shell_keys'][i];
        newShellList.appendChild(shellLi);
      };

      serverLi.appendChild(newShellList);
      newServerList.appendChild(serverLi);
    };

    shellServerElement = document.getElementById('shell_servers');
    shellServerElement.innerHTML = "";
    shellServerElement.appendChild(newServerList);
  };

  // The generic message handler for everything coming in from a websocket.
  var handleMessage = function(msg) {
    switch(msg.type) {
      case 'server_list':
        for (i in msg.servers) { updateServer(msg.servers[i]); };
        drawServers();
        break;
      default:
        console.log(msg);
    };
  };

  // Loop through all shell elements and hide them from being displayed.
  var hideAllShells = function() {
    shellElements = document.getElementById('shells').childNodes;
    for (i in shellElements) {
      node = shellElements[i];

      if (node.nodeType !== 3 && node.style !== undefined) {
        node.style.display = 'none';
      };
    };
  };

  // Request a new shell for the specific server, if the server accepts it it's
  // message will trigger the new shell display.
  var newShell = function(server_uuid) {
    shell_request = {};
    shell_request['type'] = 'new_shell';
    shell_request['server'] = server_uuid;
    window.ws.send(JSON.stringify(shell_request));
  };

  // Handles opening new and existing shells. If the shell_id is missing it
  // assumes a new shell needs to be created, otherwise it'll attempt to
  // display the existing shell. Due to the initial state required we can't
  // attempt to rejoin another shell yet, however, shells other than the
  // current one can simple be hidden.
  var openShell = function(server_uuid, shell_id) {
    if (window.servers[server_uuid] !== undefined) {
      if (shell_id === undefined) {
        newShell(server_uuid);
      } else {
        // Attempt to display a hidden shell
        showShell(server_uuid, shell_id);
      }
    } else {
      console.log("Attempted to open a shell to a server that doesn't exist.");
    };
  };

  // Display an already existing shell.
  var showShell = function(server_uuid, shell_id) {
    node = document.getElementById(server_uuid + ':' + shell_id);

    if (node !== undefined) {
      // Hide all the shells before displaying a new one.
      hideAllShells();
      node.style.display = 'block';
    } else {
      console.log("Error: Attempted to display shell that doesn't exist");
    };
  };

  // When a change is reported about a server we can use the data provided from
  // the websocket to update our server list.
  var updateServer = function(server) {
    window.servers[server.uuid] = {};
    window.servers[server.uuid]['name'] = server.name;
    window.servers[server.uuid]['shell_keys'] = server.shell_keys;
  };

  // Setup the websocket when the page finishes loading as well as the message
  // handlers.
  window.onload = function() {
    (function() {
      ws           = new WebSocket('ws://' + window.location.host + '/sockets');

      ws.onopen    = function()    { console.log('Websocket opened.'); };
      ws.onclose   = function()    { console.log('Websocket closed.'); };
      ws.onerror   = function(msg) { console.log(msg); };
      ws.onmessage = function(msg) { handleMessage(JSON.parse(msg.data)); };

      window.ws = ws;
    })();
  };
</script>
