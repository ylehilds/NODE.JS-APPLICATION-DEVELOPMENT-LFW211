function doTask (amount) {
  if (typeof amount !== 'number') throw new TypeError('amount must be a number')
  if (amount <= 0) throw new RangeError('amount must be greater than zero')
  return amount / 2
}


// console.log(doTask('here is some invalid input'))
console.log(doTask(-1))