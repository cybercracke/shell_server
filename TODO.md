
Things that I want to accomplish in this that I still have to work on, roughly
in order:

* Scroll-back buffers
* Character output buffers w/ interval flushing
* Rework communication to meet new simplified message formats
  * Inform server when web client closes (remove all shells for client)
* Shell & Thread cleanup, disable sending keys when current shell is inactive
* Clean up the code, document it
  * Templated HTML would help with this (Maybe mustache?
    http://www.sitepoint.com/creating-html-templates-with-mustachejs/)
* Friendly server/shell names
* Add a latency visualization (data can be sourced from ping messages in
  communication rework)
* Add a damn UI
* Terminal resizing
* Terminal recording and playback (we have all the input to the terminal
  emulator and potentially timing data, why not? Could be useful for training
  or auditing)
