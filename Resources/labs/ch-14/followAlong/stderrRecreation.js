// The below example is purely for purposes of enhancing understanding, always use process.stdout and process.stderr, do not try to recreate them as they've been enhanced with other characteristics beyond this basic example.

'use strict'
const fs = require('fs')
const myStdout = fs.createWriteStream(null, {fd: 1})
const myStderr = fs.createWriteStream(null, {fd: 2})
myStdout.write('stdout stream')
myStderr.write('stderr stream')

// terminal commands:
// node -p "crypto.randomBytes(100).toString('hex')" | node stderrTransformed.js > out.txt
// node -p "fs.readFileSync('out.txt').toString()"

// While it's beyond the scope of Node, it's worth knowing that if we wanted to redirect the STDERR output to another file on the command line 2> can be used:
// node -p "crypto.randomBytes(100).toString('hex')" | node stderrTransformed.js > out.txt 2> err.txt
// node -p "fs.readFileSync('err.txt').toString()"
// node -p "fs.readFileSync('out.txt').toString()"

