function f (n = 99) {
  debugger
  if (n === 0) throw Error()
  f(n - 1)
}
f()

// terminal command: node --inspect app.js a note on this is that this is the right command to make it stop on debugger keyword, but I can't make it to stop and therefore I use the flag --inspect-brk then run to nect break point which is the debugger keyword.
// then on the browser go to: chrome://inspect, then find the
// process under "Remote Targets", clicking "inspect" and ensuring the "Sources" tab is selected
