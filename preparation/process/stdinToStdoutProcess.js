// Task: Read process.stdin and pipe to process.stdout

// process.stdin.resume()
// console.log('Enter the data to be displayed ');
// process.stdin.on('data', function(data) { process.stdout.write(data) })

process.stdin.pipe(process.stdout)