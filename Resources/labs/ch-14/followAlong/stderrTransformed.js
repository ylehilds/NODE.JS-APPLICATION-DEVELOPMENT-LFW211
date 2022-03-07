'use strict'
console.error(process.stdin.isTTY ? 'terminal' : 'piped to')

const { Transform } = require('stream')
const createUppercaseStream = () => {
  return new Transform({
    transform (chunk, enc, next) {
      const uppercased = chunk.toString().toUpperCase()
      next(null, uppercased)
    }
  })
}

const uppercase = createUppercaseStream()

process.stdin.pipe(uppercase).pipe(process.stdout)

// terminal commands:
// node -p "crypto.randomBytes(100).toString('hex')" | node stderrTransformed.js > out.txt
// node -p "fs.readFileSync('out.txt').toString()"

// While it's beyond the scope of Node, it's worth knowing that if we wanted to redirect the STDERR output to another file on the command line 2> can be used:
// node -p "crypto.randomBytes(100).toString('hex')" | node stderrTransformed.js > out.txt 2> err.txt
// node -p "fs.readFileSync('err.txt').toString()"
// node -p "fs.readFileSync('out.txt').toString()"

