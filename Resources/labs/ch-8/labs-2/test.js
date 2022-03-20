const { promisify } = require('util')

async function fn(cb) {
  return cb(null, 'hello world');
}
const callbackFunction = promisify(fn); // Takes a function following the common error-first callback style, i.e. taking a (err, value) => ... callback as the last argument, and returns a version that returns promises.
// because the above returns no errors "null", then the data gets returned automatically and assigns it to callbackFunction

// callbackFunction((err, ret) => {
//   if (err) throw err;
//   console.log(ret);
// });

async function operate () {
  console.log(await callbackFunction())
}

operate()


// An arrow function is declared with a fat arrow/hash rocket (=>). In the case that your arrow function has a single expression as the function body, that expression will be executed, and the resulting value will be implicitly returned when the function is called.
// const implicit = () => 'awesome'
// implicit()    // returns 'awesome'