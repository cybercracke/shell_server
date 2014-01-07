// Global for holding the current list of known servers and shells.
window.servers = {};

// Anytime the server list gets updated we'll need to redraw the list. This
// function handles it.
window.drawServers = function() {
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
  if (shellServerElement === null) {
    return;
  };

  shellServerElement.innerHTML = "";
  shellServerElement.appendChild(newServerList);
};

// The generic message handler for everything coming in from a websocket.
window.handleMessage = function(msg) {
  switch(msg.type) {
    case 'shells:servers':
      for (i in msg.data.servers) { window.updateServer(msg.data.servers[i]); };
      window.drawServers();
      break;
    default:
      console.log(msg);
  };
};

// Loop through all shell elements and hide them from being displayed.
window.hideAllShells = function() {
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
window.newShell = function(server_uuid) {
  message = {};
  message['uuid'] = server_uuid;
  window.sendMessage('new', message);
};

// Handles opening new and existing shells. If the shell_id is missing it
// assumes a new shell needs to be created, otherwise it'll attempt to
// display the existing shell. Due to the initial state required we can't
// attempt to rejoin another shell yet, however, shells other than the
// current one can simple be hidden.
window.openShell = function(server_uuid, shell_id) {
  if (window.servers[server_uuid] !== undefined) {
    if (shell_id === undefined) {
      window.newShell(server_uuid);
    } else {
      // Attempt to display a hidden shell
      window.showShell(server_uuid, shell_id);
    }
  } else {
    console.log("Attempted to open a shell to a server that doesn't exist.");
  };
};

// Sends a message of our data type through the websocket.
window.sendMessage = function(type, data) {
  shell_request = {};
  shell_request['type'] = 'shells:' + type;
  shell_request['data'] = data

  if (window.ws.readyState == 1) {
    window.ws.send(JSON.stringify(shell_request));
  } else {
    console.log("Websocket isn't available for writing");
  };
};

// Display an already existing shell.
window.showShell = function(server_uuid, shell_id) {
  node = document.getElementById(server_uuid + ':' + shell_id);

  if (node !== undefined) {
    // Hide all the shells before displaying a new one.
    window.hideAllShells();
    node.style.display = 'block';
  } else {
    console.log("Error: Attempted to display shell that doesn't exist");
  };
};

// When a change is reported about a server we can use the data provided from
// the websocket to update our server list.
window.updateServer = function(server) {
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
