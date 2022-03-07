'use strict'
const { watch } = require('fs')

watch('.', (evt, filename) => {
  console.log(evt, filename)
})

// Creating a new file named test (node -e "fs.writeFileSync('test', 'test')") generates an event called rename.
//   Creating a folder called test-dir (node -e "fs.mkdirSync('test-dir')") generates an event called rename.
//   Setting the permissions of test-dir (node -e "fs.chmodSync('test-dir', 0o644)") generates an event called rename.
//   Writing the same content to the test file (node -e "fs.writeFileSync('test', 'test')") generates an event named change.
//   Setting the permissions of test-dir (node -e "fs.chmodSync('test-dir', 0o644)") a second time generates a change event this time.
//   Deleting the test file (node -e "fs.unlinkSync('test')") generates a rename event.