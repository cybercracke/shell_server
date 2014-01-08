
# Shell Server

This is an attempt to get command line shells from remote machines into a web
interface. It currently makes use of Redis as the placeholder and all traffic
is sent as plaintext, neither of which are good for production environments.

Quite a bit of this code is verrrryyy prototypy. There are exactly 0 tests and
a bunch of lines of undocumented vanilla JS. The ruby portions of the webserver
are pretty straight forward, but venture into the shell server and you're once
again wading into dangerous waters.

To setup and use you need to have redis install locally but not running, there
is a config file that will handle it for you. Make sure you're bundled then
start everything up with:

```
foreman start
```

This was developed using MRI ruby 2.1.0p0 on Fedora 19 and I haven't tested it
using anything else.

At the current stage I'm also not handling terminal control characters or color
sequences, so a lot of things will look funny until I get down into the depths
and get that working.

I'd also like to see it prompt for credentials like a proper login shell but I
haven't figured that out yet.

Please also be aware that I've put almost no effort into styling this thing.
It's purely for proof-of-concept.

