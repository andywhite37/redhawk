# Redhawk

A promise library for Haxe.

This library is mostly inspired by the
[Bluebird](https://github.com/petkaantonov/bluebird) promise library for
JavaScript.  This library also attempts to conform to the [Promises A+
spec](https://promisesaplus.com/) where possible.  There are a few cases
with a typed library where it is difficult to completely conform.

## Installation

```sh
$ haxelib git redhawk git@github.com:andywhite37/redhawk master src
```

## Example

```haxe
package ;

import haxe.Timer;
import js.Error;
import redhawk.Promise;

class Main {
  public static function main() {
    trace("Starting!");

    new Promise(function(resolve, reject) {
      Timer.delay(function() {
        resolve("First value");
      }, 0);
    })

    // .then functions must return a promise
    .then(function(value) {
      trace(value);

      // Return a plain value (which will be coerced into a fulfilled promise)
      return "Second value";
    })

    .then(function(value) {
      trace(value);
      // Return a promise of a new value
      return new Promise(function(resolve, reject) {
        Timer.delay(function() {
          resolve("Third value");
        }, 0);
      });
    })

    .then(function(value) {
      trace(value);

      // Shortcut for creating a fulfilled promise
      return Promise.fulfilled("Fourth value");
    })

    .then(function(value) {
      trace(value);
      // Thrown exceptions are coerced into rejected promises
      throw new Error("something went wrong!");
    })

    // .end is like .then except that it cannot return a value nor promise.  This should
    // be used at the end of the promise chain, when you don't need/want to return a new value.
    // This is not like the `.done` method of libraries like Q.
    .end(function(value) {
      trace("Should not get here");
    }, function(reason) {
      trace('Oops: ${reason.value}');
    });

    // All then functions are invoked asynchronously
    trace("...just started");
  }
}
```

## API Reference

### Promise

#### Construction

`new Promise(?name, resolver)`

* Constructs a new promise instance.
* name - optional name for the promise (for debugging)
* resolver - `function(resolve, reject) { ... }`

```haxe
// Fulfill the promise synchronously with a value.  Any .then callbacks will
// be invoked on the next tick.
var promise = new Promise(function(resolve, reject) {
  resolve("
});

// Fulfill the promise with a value asynchronously
var promise = new Promise(function(resolve, reject) {
  Timer.delay(function() {
    resolve("This is the value!");
  }, 0);
});

// Reject the promise
var promise = new Promise(function(resolve, reject) {
  // Reject with any reason (will be coerced into a `Reason` object)
  reject("My reason");

  // or reject with any object instance:
  // reject(new Error("my error message"));

  // or throw an Error - will be caught and turned into a rejection
  // throw new Error("my error message");
});
```

#### Static helpers

`Promise.tries(function() { ... })`

* Executes a callback and expects the return of a new Promise instance.
* A thrown exception is caught and turned into a rejected promise.

```haxe
Promise.tries(function() {
  // ...do something

  return new Promise(function(resolve, reject) {
    // resolve or reject
  });
});
```

`Promise.fulfilled(value)`

* Creates a promise that is fulfilled with the given value
* Value can be any type
* Shorthand for:

```haxe
new Promise(function(resolve, reject) {
  resolve(value);
});
```

`Promise.rejected(reason)`

* Creates a promise that is rejected with the given reason
* reason can be any type, and is implicitly converted to a `Reason` wrapper object.
* Shorthand for:

```haxe
new Promise(function(resolve, reject) {
  reject(reason);
});
```

#### Chaining

`promise.then(?onFulfilled, ?onRejected)`

* `.then` always return s new promise
* onFulfilled is a function that accepts a value
* onRejected is a function that accepts a reason
* onFulfilled and onRejected are both optional, but if present, must
  return a new promise or value, or throw an error.

```haxe
somePromise
  .then(function(value) {
    // Handle the value from somePromise

    // return a new value (which will be converted to a Promise)
    return "another value";

    // or return a promise
    return Promise.fulfilled("another value");
    return Promise.rejected("some error message");

    // or throw any object (which will be converted to a rejected promise)
    throw new Error("some error");
  }, function(reason) {
    // Handle the reason - access the rejection/thrown object using `reason.value`
    trace('Something went wrong: ${reason.value}');

    // Return a new promise or value
    return Promise.fulfilled("new value");
  })
```

