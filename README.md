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
    - [Chaining](#chaining)
      - [`promise.then(?onFulfillment, ?onRejection)`](#promisethenonfulfillment-onrejection)
      - [`promise.end(?onFulfillment, ?onRejection)`](#promiseendonfulfillment-onrejection)
      - [`promise.catches(onRejection)`](#promisecatchesonrejection)
      - [`promise.catchesEnd(onRejection)`](#promisecatchesendonrejection)
      - [`promise.delay(ms)`](#promisedelayms)
      - [`promise.tap(callback)`](#promisetapcallback)
    - [Static helpers](#static-helpers)
      - [`Promise.tries(function() { ... })`](#promisetriesfunction---)
      - [`Promise.all(inputs)`](#promiseallinputs)
      - [`Promise.any(inputs)`](#promiseanyinputs)
      - [`Promise.many(inputs, manyCount)`](#promisemanyinputs-manycount)
      - [`Promise.settled(promisesOrValues)`](#promisesettledpromisesorvalues)
      - [`Promise.map(inputs, mapper)`](#promisemapinputs-mapper)
      - [`Promise.reduce(inputs, reducer, initialValue)`](#promisereduceinputs-reducer-initialvalue)
      - [`Promise.each(inputs, callback)`](#promiseeachinputs-callback)
      - [`Promise.filter(inputs, filterer)`](#promisefilterinputs-filterer)
      - [`Promise.delayed(ms)`](#promisedelayedms)

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

# build command
haxe build.hxml
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

##### `promise.end(?onFulfillment, ?onRejection)`

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

##### `promise.delay(ms)`

* Adds a time delay to a promise chain
* Returns a promise that is resolved with Nil.nil
* TODO: should this resolve the previous promise's value?

```haxe
somePromise
  .delay(500)
  .end(function(_) {
    // executed after 500ms delay
  });
```

##### `promise.tap(callback)`

* `callback` is `function(value) { ... }`
* Injects a callback into a promise chain which receives the value from
  the previous promise, and returns a Promise that is resolved with the
same value.

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

##### `Promise.all(inputs)`

* `inputs` is a (mixed) array of promises or values
* Returns a promise that is fulfilled when all of the inputs promises or
  values are fulfilled.  This fulfillment value of the returned promise
is a (mixed) array the results of the input promises or values.
* If any input promise is rejected, the returned promise is rejected
  with that reason.

```haxe
Promise.all(["test1", Promise.fulfilled("test2"), "test3"])
  .end(function(results) {
    for(result in results) {
      trace(result);
    }
  }, function(reason) {
    trace("Something was rejected");
  });
```

##### `Promise.any(inputs)`

* Returns a Promise that is fulfilled with the value of the first input
  promise that is fulfilled.
* Returned promise is rejected if all input promises are rejected.

```haxe
Promise.any([Promise.rejected("test1"), "test2"])
  .end(function(result) {
    // result == "test2"
  });
```

##### `Promise.many(inputs, manyCount)`

* Returns a Promise that is fulfilled with an array of `manyCount` values
for the first `manyCount` input promises or values that are fulfilled.
* The result value indices do not correspond to the input indices. (TODO is
  this a good idea?)
* Returned promise is rejected if fewer than `manyCount` input promises
  are fulfilled.

```haxe
Promise.many([Promise.rejected("test1"), "test2", Promise.rejected("test3"), "test4", "test5"], 2)
  .end(function(results) {
    // results.length == 2
    // results[0] == "test2"
    // results[1] == "test4"
  });
```

##### `Promise.settled(promisesOrValues)`

* `promiseOrValues` is an (mixed) array of promises or values
* The returned promises is fulfilled with an array of settled promises,
which could be either fulfilled or rejected.
* Inspect the state of each promise to determine whether it was
  fulfilled or rejected.

```haxe
Promise.settled(["test1", Promise.fulfilled(1), Promise.rejected(false)])
  .end(function(promises) {
    for (promise in promises) {
      if (promise.isFulfilled()) {
        trace(promise.getValue());
      } else if (promise.isRejected()) {
        trace(promise.getReason());
      }
    }
  });

```

##### `Promise.map(inputs, mapper)`

TODO

##### `Promise.reduce(inputs, reducer, initialValue)`

TODO

##### `Promise.each(inputs, callback)`

TODO

##### `Promise.filter(inputs, filterer)`

TODO

##### `Promise.delayed(ms)`

* Creates a promise that is fulfilled with nil after a `ms` time delay
* See also `.delay(ms)` member function

```haxe
Promise.delayed(500)
  .end(function(_) {
    // executed after 500ms delay
  });
```
