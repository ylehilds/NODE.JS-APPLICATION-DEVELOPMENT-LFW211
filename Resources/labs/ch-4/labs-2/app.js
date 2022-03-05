function f (n = 99) {
  debugger
  if (n === 0) throw Error()
  f(n - 1)
}
f()
