// Task: Create a string buffer that is 256 bytes long

const buf = Buffer.alloc(256);
const len = buf.write("Simply Easy Learning");
const json = buf.toJSON(buf);

console.log("Octets written : "+  len);
console.log("buffer content string: "+  buf.toString());
console.log("buffer content base64: "+  buf.toString('base64'));
console.log(json);