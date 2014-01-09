
{
  so: <source (required for everything but websocket sources>,
  de: <dest -> optional>,
  da: <data object -> optional>,
  ty: <message type>
}

Specific messages:

server:add    {'so' => '<source>', 'de' => '<dest|nil>', 'ty' => 'server:add',    'da' => {'id' => '<uuid>', 'name' => '<name>'}}
server:remove {'so' => '<source>', 'de' => '<dest|nil>', 'ty' => 'server:remove', 'da' => '<uuid>'}
server:list   {'so' => '<source>', 'de' => '<dest|nil>', 'ty' => 'server:list',   'da' => [{'id' => '<uuid>', 'name' => '<name>'}, ... ]}

shell:keys    {'so' => '<source>', 'de' => '<dest>', 'ty' => 'shell:keys',   'da' => {'id' => '<shell-id>', 'chars' => '<chars>', 'time' => <time>}}
shell:request {'so' => '<source>', 'de' => '<dest>', 'ty' => 'shell:request'}
shell:opened  {'so' => '<source>', 'de' => '<dest>', 'ty' => 'shell:opened', 'da' => '<shell-id>'}
shell:closed  {'so' => '<source>', 'de' => '<dest>', 'ty' => 'shell:closed', 'da' => '<shell-id>'}

client:disconnect {'so' => '<source>', 'ty' => 'client:disconnect', 'da' => '<client-id>'}

ping  {'so' => '<source>', 'de' => '<dest>', 'ty' => 'ping', 'da' => '<sources time>'}
pong  {'so' => '<source>', 'de' => '<dest>', 'ty' => 'pong', 'da' => '<sources time>'}

In the event a client closes the web server should generate a client:disconnect
to allow servers to clean up shells left behind.

Sample generation:

uuid -> SecureRandom.uuid.gsub('-', '')
id   -> SecureRandom.hex(4)
time -> (Time.now.to_f * 1000).round


