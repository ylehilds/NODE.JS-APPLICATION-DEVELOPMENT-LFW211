const {Transform} = require('stream')

const upperCaseTransform = new Transform({
  transform: (chunk, encoding, done) => {
    const result = chunk.toString().toUpperCase()
    done(null, result)
  }
})

if (require.main === module) {
  process.stdin.pipe(process.stdout)
} else {
  process.stdin
    .pipe(upperCaseTransform)
    .pipe(process.stdout)
}