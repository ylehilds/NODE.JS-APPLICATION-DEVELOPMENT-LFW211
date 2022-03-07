// terminal commands:

//  node -p "stream + ''"
// output: function Stream(opts) {
//   EE.call(this, opts);
// }

// node -p "stream.prototype"
// output: EventEmitter { pipe: [Function (anonymous)] }
//
// node -p "Object.getPrototypeOf(stream.prototype)"
// output: {
//   _events: undefined,
//     _eventsCount: 0,
//     _maxListeners: undefined,
//     setMaxListeners: [Function: setMaxListeners],
//   getMaxListeners: [Function: getMaxListeners],
//   emit: [Function: emit],
//   addListener: [Function: addListener],
//   on: [Function: addListener],
//   prependListener: [Function: prependListener],
//   once: [Function: once],
//   prependOnceListener: [Function: prependOnceListener],
//   removeListener: [Function: removeListener],
//   off: [Function: removeListener],
//   removeAllListeners: [Function: removeAllListeners],
//   listeners: [Function: listeners],
//   rawListeners: [Function: rawListeners],
//   listenerCount: [Function: listenerCount],
//   eventNames: [Function: eventNames]
// }

// The following is an example demonstrating the consuming of a readable stream:

'use strict'
const fs = require('fs')
const readable = fs.createReadStream(__filename)
readable.on('data', (data) => { console.log(' got data', data) })
readable.on('end', () => { console.log(' finished reading') })