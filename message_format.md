
{
  so: <source (required for everything but websocket sources>,
  de: <dest -> optional>,
  da: <data object>,
  ty: <message type>
}

value message types:

keys:<shellid> => key presses that are part of a shell session
servers        => new list of servers
shell:new      => spawn a new shell on a target server

data contents for different types:

keys:<shell>: <str>
servers:      [{'name' => '<server name>', 'uuid' => '<server uuid>'}]
servers:new   "<uuid of server>"
shell:new:    "" | "<key>"

