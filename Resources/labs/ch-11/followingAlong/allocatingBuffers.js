// terminal commands:

//  node -p "Buffer.allocUnsafe(10)"
// output <Buffer 00 00 00 00 00 00 00 00 00 00>

// const buffer = Buffer.from('hello world')

// terminal: node -p "Buffer.from('hello world')"
// output: <Buffer 68 65 6c 6c 6f 20 77 6f 72 6c 64>

console.log('👀'.length) // will print 2
console.log(Buffer.from('👀').length) // will print 4

// terminal commands:

// node -p "'👀'.length"
// node -p "Buffer.from('👀').length"
// node -p "Buffer.from('👀')"
// node -p "Buffer.from('👀', 'utf16le')"
// node -p "Buffer.from('A')"
// node -p "Buffer.from('A', 'utf16le')"

// node -p "Buffer.from('8J+RgA==', 'base64')"
// node -p "Buffer.from('👀')"

let buffer = Buffer.from('👀')
console.log(buffer) // prints <Buffer f0 9f 91 80>
console.log(buffer.toString()) // prints 👀
console.log(buffer + '') // prints 👀


let buffer = Buffer.from('👀')
console.log(buffer) // prints <Buffer f0 9f 91 80>
console.log(buffer.toString('hex')) // prints f09f9180
console.log(buffer.toString('base64')) // prints 8J+RgA==

const { StringDecoder } = require('string_decoder')
const frag1 = Buffer.from('f09f', 'hex')
const frag2 = Buffer.from('9180', 'hex')
console.log(frag1.toString()) // prints �
console.log(frag2.toString()) // prints ��
const decoder = new StringDecoder()
console.log(decoder.write(frag1)) // prints nothing
console.log(decoder.write(frag2)) // prints 👀


let buffer = Buffer.from('👀')
const json = JSON.stringify(buffer)
const parsed = JSON.parse(json)
console.log(parsed) // prints { type: 'Buffer', data: [ 240, 159, 145, 128 ] }
console.log(Buffer.from(parsed.data)) // prints <Buffer f0 9f 91 80>


