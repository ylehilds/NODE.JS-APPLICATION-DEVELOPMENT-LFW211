'use strict'
const { join, resolve } = require('path')
const { watch, readdirSync, statSync } = require('fs')

const cwd = resolve('.')
const files = new Set(readdirSync('.'))
watch('.', (evt, filename) => {
  try {
    const { ctimeMs, mtimeMs } = statSync(join(cwd, filename))
    if (files.has(filename) === false) {
      evt = 'created'
      files.add(filename)
    } else {
      if (ctimeMs === mtimeMs) evt = 'content-updated'
      else evt = 'status-updated'
    }
  } catch (err) {
    if (err.code === 'ENOENT') {
      files.delete(filename)
      evt = 'deleted'
    } else {
      console.error(err)
    }
  } finally {
    console.log(evt, filename)
  }
})

// Creating a new file named test (node -e "fs.writeFileSync('test', 'test')") generates an event called rename.
//   Creating a folder called test-dir (node -e "fs.mkdirSync('test-dir')") generates an event called rename.
//   Setting the permissions of test-dir (node -e "fs.chmodSync('test-dir', 0o644)") generates an event called rename.
//   Writing the same content to the test file (node -e "fs.writeFileSync('test', 'test')") generates an event named change.
//   Setting the permissions of test-dir (node -e "fs.chmodSync('test-dir', 0o644)") a second time generates a change event this time.
//   Deleting the test file (node -e "fs.unlinkSync('test')") generates a rename event.