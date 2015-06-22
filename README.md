# Redhawk

A promise library for Haxe.

This library is mostly inspired by the
[Bluebird](https://github.com/petkaantonov/bluebird) promise library for
JavaScript.  This library also attempts to conform to the [Promises A+
spec](https://promisesaplus.com/) where possible.  There are a few cases
with a typed library where it is difficult to completely conform.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Installation](#installation)
- [Example](#example)
- [API Reference](#api-reference)
  - [Promise](#promise)
    - [Construction](#construction)
      - [`new Promise(?name, resolver)`](#new-promisename-resolver)
      - [`Promise.fulfilled(value)`](#promisefulfilledvalue)
      - [`Promise.rejected(reason)`](#promiserejectedreason)
    - [Static helpers](#static-helpers)
      - [`Promise.tries(function() { ... })`](#promisetriesfunction---)
    - [Chaining](#chaining)
      - [`promise.then(?onFulfillment, ?onRejection)`](#promisethenonfulfillment-onrejection)
      - [`promise.end(onFulfillment, onRejection)`](#promiseendonfulfillment-onrejection)
      - [`promise.catches(onRejection)`](#promisecatchesonrejection)
      - [`promise.catchesEnd(onRejection)`](#promisecatchesendonrejection)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

```sh
$ haxelib git redhawk git@github.com:andywhite37/redhawk master src
```

## Example

```haxe
// Main.hx
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

    // No rejection handler - the Error from above should propagate through
    // this then call.
    .then(function(value) {
      throw new Error('We should not have gotten here!');
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

Build & run for Node.js:

```
# build.hxml
-lib redhawk
-D no-deprecation-warnings
-main Main
-js main.js
-cmd node main.js
```

Outputs:

```
Starting!
...just started
First value
Second value
Third value
Fourth value
Oops: Error: something went wrong!
```

## API Reference

### Promise

#### Construction

##### `new Promise(?name, resolver)`

* Constructs a new promise instance.
* name - optional name for the promise (for debugging)
* resolver - `function(resolve, reject) { ... }`

```haxe
// Fulfill the promise synchronously with a value.  Any .then callbacks will
// be invoked on the next tick.
var promise = new Promise(function(resolve, reject) {
  resolve("some value");
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

##### `Promise.fulfilled(value)`

* Creates a promise that is fulfilled with the given `value`
* `value` can be any type
* Shorthand for:

```haxe
new Promise(function(resolve, reject) {
  resolve(value);
});
```

##### `Promise.rejected(reason)`

* Creates a promise that is rejected with the given `reason`
* `reason` can be any type, and is implicitly converted to a `Reason` wrapper object.
* Shorthand for:

```haxe
new Promise(function(resolve, reject) {
  reject(reason);
});
```

#### Static helpers

##### `Promise.tries(function() { ... })`

* Executes a function and expects the return of a new Promise instance.
* A thrown error/etc. is caught and turned into rejected promise.

```haxe
Promise.tries(function() {
  // ...do something
  // If this throws, it will be caught and turned into a rejected promise

  return new Promise(function(resolve, reject) {
    // resolve or reject
  });
});
```

#### Chaining

##### `promise.then(?onFulfillment, ?onRejection)`

* `.then` must always return a new Promise or value (which is turned
  into a promise), or throw.
* `onFulfillment` is: `function(value) { ... }`
* `onRejection` is: `function(reason) { ... }`
* `onFulfillment` and `onRejection` are both optional, but if present, each must
  return a new promise or value, or throw an error.
* If you don't want to return a value/promise, use `.end(...)` instead.

```haxe
somePromise
  .then(function(value) {
    // Handle the value from somePromise...

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

    // If the onRejection function is not provided, any rejections from
    // above promises will be propagated to the next handler.
  })
```

##### `promise.end(onFulfillment, onRejection)`

* Same as `.then` except that the `onFulfillment` and `onRejection`
  functions cannot return a new promise/value.
* The promise chain ends with `.end`.
* The reason for this method to exist is that Haxe is a typed language,
  and the type signature of `.then` expects a return value.
* Note: `.end` is not the same concept as the `.done` method of
  libraries like [Q](https://github.com/kriskowal/q).  In Redhawk,
  unhandled errors are automatically thrown if unhandled after the next
  tick.

```haxe
somePromise
  .then(function(value) {
    trace('got value: $value');
    return "new value";
  })
  .end(function(value) {
    trace('got another value $value');
  }, function(reason) {
    trace('got a rejection ${reason.value}');
  });
```

##### `promise.catches(onRejection)`

* Shorthand for `.then(null, onRejection)`

##### `promise.catchesEnd(onRejection)`

* Shorthand for `.end(null, onRejection)`
