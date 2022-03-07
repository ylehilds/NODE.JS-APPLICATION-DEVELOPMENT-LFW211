// terminal commands:
// node -p "crypto.randomBytes(100).toString('hex')"
//
const { exec } = require("child_process");
exec("echo $?", (error, stdout, stderr) => {
  if (error) {
    console.log(`error: ${error.message}`);
    return;
  }
  if (stderr) {
    console.log(`stderr: ${stderr}`);
    return;
  }
  console.log(`stdout for echo $? command it just tells you the last process exit code 0 is success, anything else is an error: ${stdout}`);
});

// console.log('exit after this')
//
//
// 'use strict'
// setInterval(() => {
//   console.log('this interval is keeping the process open')
// }, 500)


'use strict'
setInterval(() => {
  console.log('this interval is keeping the process open')
}, 500)
setTimeout(() => {
  console.log('exit after this')
  process.exit(1)
}, 1750)


// terminal command: echo $?
// output: 0 // stdout for echo $? command it just tells you the last process exit code 0 is success, anything else is an error

