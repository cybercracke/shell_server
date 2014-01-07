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

// Source for key press numbers:
//  http://www.cambiaresearch.com/articles/15/javascript-char-codes-key-codes
// Source for ANSI escape sequences:
//  http://ascii-table.com/ansi-escape-sequences-vt-100.php
window.keyDownHandler = function(evnt) {
  var charStr = "";

  // Lookup / convert key press ID's into their ANSI escape sequences
  switch (evnt.keyCode) {
    case 8: charStr = ""; break;        // Backspace
    case 9: charStr = "\t"; break;      // Tab
    case 13: charStr = "\r"; break;     // 'Enter', may need a '\n' as well
    case 27: charStr = "\x1b"; break;   // Esc
    case 33:                            // Page up
      if (evnt.ctrlKey) {
        console.log('This should scroll the display up by the height of the terminal');
      } else {
        charStr = "\x1b[5~";
      }
      break;
    case 34:                            // Page down
      if (evnt.ctrlKey) {
        console.log('This should scroll the display down by the height of the terminal');
      } else {
        charStr = "\x1b[6~";
      }
      break;
    case 35: charStr = "\x1bOF"; break; // End
    case 36: charStr = "\x1bOH"; break; // Home
    case 37: charStr = "\x1b[D"; break; // Left arrow
    case 38:                            // Up arrow
      if (evnt.ctrlKey) {
        console.log('This should scroll the display up by one line');
      } else {
        charStr = "\x1b[A";
      }
      break;
    case 39: charStr = "\x1b[C"; break; // Right arrow
    case 40:                            // Down arrow
      if (evnt.ctrlKey) {
        console.log('This should scroll the display down by one line');
      } else {
        charStr = "\x1b[B";
      }
      break;
    case 45: charStr = "\x1b[2~"; break; // Insert
    case 46: charStr = "\x1b[3~"; break; // Delete
    default:
      if (evnt.ctrlKey) {
        if (evnt.keyCode >= 65 && evnt.keyCode <= 90) {
          charStr = String.fromCharCode(evnt.keyCode - 64);
        } else if (evnt.keyCode == 32) {
          charStr = String.fromCharCode(0);
        }
      } else if (evnt.altKey || evnt.metaKey) {
        if (evnt.keyCode >= 65 && evnt.keyCode <= 90) {
          charStr = "\x1b" + String.fromCharCode(evnt.keyCode + 32);
        }
      }
      break;
  }

  if (charStr) {
    if (evnt.stopPropagation) evnt.stopPropagation();
    if (evnt.preventDefault) evnt.preventDefault();

    window.key_rep_state = 1;
    window.key_rep_str = charStr;
    window.sendMessage("keyboard", escape(charStr));

    return false;
  } else {
    window.key_rep_state = 0;
    return true;
  }
};

// Handle long key presses and key repeats.
window.keyPressHandler = function(evnt) {
  if (evnt.stopPropagation) evnt.stopPropagation();
  if (evnt.preventDefault) evnt.preventDefault();

  var charStr = "", code = 0;

  if (('charCode' in evnt) !== -1) {
    code = evnt.charCode;
  } else {
    code = evnt.keyCode;

    if (window.key_rep_state == 1) {
      window.key_rep_state = 2;
      return false;
    } else if (this.key_rep_state == 2) {
      charStr = window.key_rep_str;
    }
  };

  if (code != 0) {
    if (!evnt.ctrlKey && (!evnt.altKey || !evnt.metaKey)) {
      charStr = String.fromCharCode(code);
    };
  };

  if (charStr) {
    window.sendMessage("keyboard", escape(charStr));
    return false;
  } else {
    return true;
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
    ws = new WebSocket('ws://' + window.location.host + '/sockets');

    ws.onopen = function()    {
      console.log('Websocket opened.');

      document.addEventListener("keydown", window.keyDownHandler, true);
      document.addEventListener("keypress", window.keyPressHandler, true);
    };

    ws.onclose = function() { console.log('Websocket closed.'); };
    ws.onerror = function(msg) { console.log(msg); };
    ws.onmessage = function(msg) { handleMessage(JSON.parse(msg.data)); };

    window.key_rep_state = 0;
    window.key_rep_str = "";

    window.ws = ws;
  })();
};
