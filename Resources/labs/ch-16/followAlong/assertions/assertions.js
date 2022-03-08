// terminal commands:
/*
node -e "assert(false)"
node -e "assert(true)"
node -e "assert({something: 'truthy'})"

If the value passed to assert is truthy then it will not throw. This is the key behavior of any assertion, if the condition is not met the assertion will throw an error. The error throw is an instance of AssertionError (to learn more see Class: assert.AssertionError).

The core assert module has the following assertion methods:

  assert.ok(val) – the same as assert(val)
assert.equal(val1, val2) – coercive equal, val1 == val2
assert.notEqual(val1, val2) – coercive unequal, val1 != val2
assert.strictEqual(val1, val2) – strict equal, val1 === val2
assert.notStrictEqual(val1, val2) – strict unequal, val1 !== val2
assert.deepEqual(obj1, obj2) – coercive equal for all values in an object
assert.notDeepEqual(obj1, obj2) – coercive unequal for all values in an object
assert.deepStrictEqual(obj1, obj2) – strict equal for all values in an object
assert.notDeepStrictEqual(obj1, obj2) – strict unequal for all values in an object
assert.throws(function) – assert that a function throws
assert.doesNotThrow(function) – assert that a function doesn't throw
assert.rejects(promise|async function) – assert promise or returned promise rejects
assert.doesNotReject(promise|async function) – assert promise or returned promise resolves
assert.ifError(err) – check that an error object is falsy
assert.match(string, regex) – test a string against a regular expression
assert.doesNotMatch(string, regex) – test that a string fails a regular expression
assert.fail() – force an AssertionError to be thrown
Since the Node core assert module does not output anything for success cases there is no assert.pass method as it would be behaviorally the same as doing nothing.

  We can group the assertions into the following categories:

  Truthiness (assert and assert.ok)
Equality (strict and loose) and Pattern Matching (match)
Deep equality (strict and loose)
Errors (ifError plus throws, rejects and their antitheses)
Unreachability (fail)

*/
