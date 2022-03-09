function f (n = 99) {
  if (n === 0) throw Error()
  f(n - 1)
}
f()

// terminal command: node --inspect-brk app.js
// then on the browser go to: chrome://inspect, then find the
// process under "Remote Targets", clicking "inspect" and ensuring the "Sources" tab is selected

