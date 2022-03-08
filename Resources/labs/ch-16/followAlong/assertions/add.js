'use strict'

// module.exports = function (num1, num2) {
//   return num1 + num2
// }

function add (num1, num2) { // this is equivalent to above exports
  return num1 + num2
}
module.exports = add

// exports.add = function (num1, num2) { // this way to export is good if in the same file you would be export ing more methods/functions. If you're just exporting 1 method, then the above method is the way to go.
//   return num1 + num2
// }
