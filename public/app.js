// Global for holding the current list of known servers and shells.
window.servers = {};

// Anytime the server list gets updated we'll need to redraw the list. This
// function handles it.
window.drawServers = function() {
  newServerList = document.createElement('ul');

  for (uuid in window.servers) {
    serverLi = document.createElement('li');
    serverLi.innerText = window.servers[uuid]['name'];

    newShellLink = document.createElement('a');
    newShellLink.href = '#';
    newShellLink.innerText = '(+ New Shell)';
    newShellLink.dataset['uuid'] = uuid;

    newShellLink.onclick = (function() {
      window.event.preventDefault();
      window.newShell(this.dataset.uuid);
    });

    shellsList = document.createElement('ul');

    for (shell_key in window.servers[uuid]['shells']) {
      shellLi = document.createElement('li');
      activeShellLink = document.createElement('a');

      activeShellLink.innerText = shell_key;
      activeShellLink.href = '#';
      activeShellLink.dataset['shell_key'] = shell_key;
      activeShellLink.dataset['uuid'] = uuid;

      activeShellLink.onclick = (function() {
        window.event.preventDefault();
        window.current_shell = this.dataset.uuid + ':' + this.dataset.shell_key;
        window.showCurrentShell();
      });

      shellLi.appendChild(activeShellLink);
      shellsList.appendChild(shellLi);
    };

    serverLi.appendChild(newShellLink);
    serverLi.appendChild(shellsList);
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
  switch(msg.ty) {
    case 'servers':
      for (i in msg.da) { window.updateServer(msg.da[i]); };
      window.drawServers();
      break;
    case 'shell:new':
      // Ensure we already know about this server ignore it otherwise
      if (msg.so in window.servers) {
        // Create the terminal
        var term = new Terminal({
          cols: 80,
          rows: 24,
          useStyle: true,
          screenKeys: false
        });

        term.on('data', function(data) {
          console.log('Term Data: ' + data);
        });

        term.on('title', function(title) {
          console.log('New Title: ' + title);
        });

        // Add the shell to known shell list
        window.servers[msg.so]['shells'][msg.da] = term;

        // Create our shell node
        newShellNode = document.createElement('div');
        newShellNode.setAttribute('id', msg.so + ':' + msg.da);
        newShellNode.className = 'hidden shell';

        // Append the shell node to the page
        shellList = document.getElementById('shells');
        shellList.appendChild(newShellNode);

        term.open(newShellNode);

        // Update the server list and show the appropriate shell
        window.drawServers();
        window.current_shell = msg.so + ':' + msg.da;
        window.showCurrentShell();
      };

      break;
    default:
      // Keys are a special case they need to be matched with a regex
      if (/^keys:/.test(msg.ty)) {
        server_uuid = msg.so;
        shell_key = msg.ty.split(':')[1];

        for (i in window.servers[uuid]['shells']) {
          if (i == shell_key) {
            window.servers[uuid]['shells'][i].write(msg.da);
          };
        };
      } else {
        console.log(msg);
      }
  };
};

// Source for key press numbers:
//  http://www.cambiaresearch.com/articles/15/javascript-char-codes-key-codes
// Source for ANSI escape sequences:
//  http://ascii-table.com/ansi-escape-sequences-vt-100.php
//
// Handles encoding almost all keypresses to be passed on to the shell.
window.keyDownHandler = function(evnt) {
  if (window.current_shell === undefined) return true;
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

    shell_parts = window.current_shell.split(':');
    window.sendMessage("keys:" + shell_parts[1], escape(charStr), shell_parts[0]);

    return false;
  } else {
    window.key_rep_state = 0;
    return true;
  }
};

// Handle long key presses, key repeats.
window.keyPressHandler = function(evnt) {
  if (window.current_shell === undefined) return true;
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
    shell_parts = window.current_shell.split(':');
    window.sendMessage("keys:" + shell_parts[1], escape(charStr), shell_parts[0]);

    return false;
  } else {
    return true;
  };
};

// Request a new shell for the specific server, if the server accepts it it's
// message will trigger the new shell display.
window.newShell = function(server_uuid) {
  if (server_uuid === undefined) {
    console.log('server_uuid needs to be defined to open a new shell.');
    return;
  };

  window.sendMessage('shell:new', '', server_uuid);
};

// Handles opening new and existing shells.  Due to the initial state required
// we can't attempt to rejoin another shell yet, however, shells other than the
// current one can simple be hidden.

window.openShell = function(server_uuid, shell_id) {
  if ((window.servers[server_uuid] !== undefined) && (shell_id in window.servers[server_uuid]['shells'])) {
    // Attempt to display a hidden shell
    window.current_shell = server_uuid + ':' + shell_id;
    window.showCurrentShell();
  } else {
    console.log("Attempted to open a shell to a server that doesn't exist.");
  };
};

// Sends a message of our data type through the websocket.
window.sendMessage = function(type, data, dest) {
  shell_request = {};
  shell_request['ty'] = type;
  shell_request['da'] = data;

  if (dest !== undefined) shell_request['de'] = dest;

  if (window.ws.readyState == 1) {
    window.ws.send(JSON.stringify(shell_request));
  } else {
    console.log("Websocket isn't available for writing.");
    window.current_shell = undefined;
  };
};

// Display an already existing shell.
window.showCurrentShell = function() {
  shell_id = window.current_shell;

  // Initially hide everything
  shells = document.getElementById('shells').childNodes;
  for (i in shells) {
    if (shells[i].nodeType !== 3) {
      shells[i].className = 'hidden shell';
    };
  };

  // If there is a shell find the node and make it visible
  if (shell_id !== undefined) {
    document.getElementById(shell_id).className = 'current shell';
  };
};

// When a change is reported about a server we can use the data provided from
// the websocket to update our server list.
window.updateServer = function(server) {
  window.servers[server.uuid] = {};
  window.servers[server.uuid]['name'] = server.name;
  window.servers[server.uuid]['shells'] = {};
};

// Setup the websocket when the page finishes loading as well as the message
// handlers.
window.onload = function() {
  (function() {
    window.current_shell = undefined;
    window.key_rep_state = 0;
    window.key_rep_str = "";

    ws = new WebSocket('ws://' + window.location.host + '/sockets');
    window.ws = ws;

    ws.onopen = function()    {
      console.log('Websocket opened.');

      document.addEventListener("keydown", window.keyDownHandler, true);
      document.addEventListener("keypress", window.keyPressHandler, true);
    };

    ws.onclose = function() { console.log('Websocket closed.'); };
    ws.onerror = function(msg) { console.log(msg); };
    ws.onmessage = function(msg) { handleMessage(JSON.parse(msg.data)); };
  })();
};

