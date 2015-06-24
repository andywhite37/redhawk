# redhawk

An experimental promise library for Haxe.

This library is mostly inspired by the
[Bluebird](https://github.com/petkaantonov/bluebird) promise library for
JavaScript.  This library also attempts to conform to the [Promises/A+
spec](https://promisesaplus.com/) where possible.  There are a few cases
with a typed library where it is difficult to completely conform.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Installation](#installation)
- [Example](#example)
- [Key concepts](#key-concepts)
- [API Reference](#api-reference)
  - [`PromiseOrValue<TValue>`](#promiseorvaluetvalue)
  - [`Reason`](#reason)
  - [`Promise<TValue>`](#promisetvalue)
    - [Promise construction](#promise-construction)
      - [`new Promise(?name, resolver)`](#new-promisename-resolver)
      - [`Promise.fulfilled(value)`](#promisefulfilledvalue)
      - [`Promise.rejected(reason)`](#promiserejectedreason)
    - [Promise chaining](#promise-chaining)
      - [`.then(?onFulfillment, ?onRejection)`](#thenonfulfillment-onrejection)
      - [`.end(?onFulfillment, ?onRejection)`](#endonfulfillment-onrejection)
      - [`.catches(onRejection)`](#catchesonrejection)
      - [`.catchesEnd(onRejection)`](#catchesendonrejection)
      - [`.finally(onFulfillmentOrRejection)`](#finallyonfulfillmentorrejection)
      - [`.finallyEnd(onFulfillmentOrRejection) : Void`](#finallyendonfulfillmentorrejection--void)
      - [`.thenFulfilled(value)`](#thenfulfilledvalue)
      - [`.thenRejected(reason)`](#thenrejectedreason)
      - [`.tap(callback)`](#tapcallback)
      - [`.delay(ms)`](#delayms)
    - [Static helpers](#static-helpers)
      - [`Promise.tries(callback)`](#promisetriescallback)
      - [`Promise.all(inputs)`](#promiseallinputs)
      - [`Promise.any(inputs)`](#promiseanyinputs)
      - [`Promise.many(inputs, manyCount)`](#promisemanyinputs-manycount)
      - [`Promise.settled(inputs)`](#promisesettledinputs)
      - [`Promise.map(inputs, mapper)`](#promisemapinputs-mapper)
      - [`Promise.each(inputs, callback)`](#promiseeachinputs-callback)
      - [`Promise.reduce(inputs, reducer, initialValue)`](#promisereduceinputs-reducer-initialvalue)
      - [`Promise.filter(inputs, filterer)`](#promisefilterinputs-filterer)
      - [`Promise.delayed(ms)`](#promisedelayedms)
    - [Promise introspection](#promise-introspection)
      - [`.isPending()`](#ispending)
      - [`.isFulfilled()`](#isfulfilled)
      - [`.isRejected()`](#isrejected)
      - [`.isSettled()`](#issettled)
      - [`.getValue()`](#getvalue)
      - [`.getReason()`](#getreason)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

```sh
# Not published to lib.haxe.org (yet)
# Install using `haxelib dev ...` or `haxelib git ...`
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

```sh
$ haxe build.hxml
```

build.hxml file:

```sh
-lib redhawk
-main Main
-js main.js
-cmd node main.js
```

`node main.js` output:

```
Starting!
...just started
First value
Second value
Third value
Fourth value
Oops: Error: something went wrong!
```

## Key concepts

The goal of this library was to leverage Haxe typing as much as possible
while keeping the API as lightweight, easy, and non-verbose as possible.
One key component in redhawk is the `PromiseOrValue<T>` abstract, which
has implicit converters from `Promise<T>` and `T`, so that methods that
return a `PromiseOrValue<T>` can simply return a raw `Promise<T>` or a
`T`, and the library will coerce everything into a `Promise<T>`.  Raw
`T` values are coerced into fulfilled `Promise<T>`s.  A similar abstract
is used for rejection "reason" objects: `Reason`.  At this time, the
underlying rejection reason is a `Dynamic` for simplicity at the expense
of type safety.

## API Reference

### `PromiseOrValue<TValue>`

An abstract type backed by an enum of either `Promise<TValue>` or
`TValue`.  Contains implicit conversions from `Promise<TValue>` and `TValue`
and an implicit convert to `Promise<TValue>`.

### `Reason`

An abstract type backed by a class that wraps a `Dynamic` value.  The
purpose of this class is to have a single rejection reason type, which
allows for any value to be used as a rejection reason.

### `Promise<TValue>`

The main `Promise` type for this library.

#### Promise construction

##### `new Promise(?name, resolver)`

Constructs a new `Promise` instance.

* `name`: `String`- optional name for the `Promise` (for debugging)
* `resolver`: `((TValue -> Void) -> (Reason -> Void) -> Void)` - resolver function,
e.g. `function(resolve, reject) { /* resolve(value) or reject(reason) */ }`
* returns: `Promise<TValue>`

Example:

```haxe
// Create a promise that is eventually fulfilled

var promise = new Promise(function(resolve, reject) {
  // Fulfill with a value
  resolve("some value");

  // Or asynchronously fulfill with a value
  Timer.delay(function() {
    resolve("This is the value!");
  }, 0);
});

// Create a Promise that is eventually rejected

var promise = new Promise(function(resolve, reject) {
  // Reject with any reason (value will be coerced into a `Reason` wrapper object)
  reject("My reason");

  // Or reject with an instance of any type (will be implicitly wrapped in a Reason object)
  reject(new js.Error("my error message"));
  reject(new MyError("my custom error"));
  reject(new MyClass("my custom error"));

  // Or throw an Error or other object.
  // The thrown object will be caught and turned into a rejected promise
  throw new Error("my error message");
  throw 'some string';

  // Or reject asynchronously
  Timer.delay(function() {
    reject('something went wrong');
  }, 0);
});
```

##### `Promise.fulfilled(value)`

Creates a new `Promise` that is fulfilled with the given `value`

* `value`: `TValue` - value with which to fulfill the new `Promise`
* returns: `Promise<TValue>` (fulfilled)

Shorthand for:

```haxe
new Promise(function(resolve, reject) {
  resolve(value);
});
```

##### `Promise.rejected(reason)`

Creates a new `Promise` that is rejected with the given `reason`

* `reason`: `Reason` - can pass any type, and it will implicitly converted to a `Reason` wrapper object
* returns: `Promise<TValue>` (rejected)

Shorthand for:

```haxe
new Promise(function(resolve, reject) {
  reject(reason);
});
```

#### Promise chaining

##### `.then(?onFulfillment, ?onRejection)`

Chains a fulfillment or rejection handler to this `Promise` When the
previous promise is fulfilled or rejected, the corresponding `.then`
fulfillment or rejection handler will be invoked on the "next tick."

* `onFulfillment`: `TValue -> PromiseOrValue<TValueNext>` - optional
  fulfillment handler, which must return a `Promise<TValueNext>` or a
`TValueNext` or throw.
* `onRejection`: `Reason -> PromiseOrValue<TValueNext>`: optional
rejection handler, which must return a `Promise<TValueNext>` or a
`TValueNext`, or throw.
* returns: `Promise<TValueNext>`

Example:

```haxe
somePromise
  .then(function(value) {
    // Handle the value from somePromise...

    // return a new value (which will be converted to a Promise)
    return "another value";

    // Or return a promise
    return Promise.fulfilled("another value");
    return Promise.rejected("some error message");

    // Or throw any object (which will be converted to a rejected promise)
    throw new Error("some error");
  }, function(reason) {
    // Handle the reason - access the rejection/thrown object using `reason.value`
    trace('Something went wrong: ${reason.value}');

    // Return a new promise or value to send to the next chained handler
    return Promise.fulfilled("new value");

    // If the onRejection function is not provided, any rejections from
    // above promises will be propagated to the next handler.
  })
```

##### `.end(?onFulfillment, ?onRejection)`

Same as `.then` except that the `onFulfillment` and `onRejection`
functions do not return a new `Promise` nor `value`.  The promise chain
ends with `.end` as it does not return a `Promise`, and no new
asynchronous work should be started in the `.end` handlers.

Note: `.end` is not the same as the `.done` method of libraries like
[Q](https://github.com/kriskowal/q).  In redhawk, unhandled errors are
automatically thrown if unhandled after the next tick.

* `onFulfillment`: `TValue -> Void`
* `onRejection`: `Reason -> Void`
* returns: `Void`

Example:

```haxe
Promise.fulfilled("test1")
  .then(function(value) {
    // value == "test1"
    return "test2";
  })
  .end(function(value) {
    // value == "test2"
    // can't return promise/value now - chain is done
  }, function(reason) {
    trace('should not have gotten here');
    // can't return promise/value now - chain is done
  });
```

##### `.catches(onRejection)`

Chains a rejection handler which must return a new `Promise<TValueNext>` or `TValueNext`

* `onRejection`: `Reason -> PromiseOrValue<TValueNext>`
* returns: `Promise<TValueNext>`

Shorthand for:

```haxe
.then(null, onRejection)`
```

##### `.catchesEnd(onRejection)`

Chains a rejection handler and ends the promise chain.

* `onRejection`: `Reason -> Void`
* returns: `Void`

Shorthand for:

```haxe
.end(null, onRejection)
```

##### `.finally(onFulfillmentOrRejection)`

Chains a handler to invoke when the previous `Promise` is settled
(either fulfilled or rejected).  Finally can perform an async operation
and return a `Promise<Nil>`, but if fulfilled, the previous `Promise` is
returned.

* `onFulfillmentOrRejection`: `Void -> Void`
* returns: `Promise<TValue>` - the previous promise (which is fulfilled
  or rejected)

Conceptually similar to the following, except returns the previous
prmoise when the handler settles:

```haxe
.then(onFulfillmentOrRejection, onFulfillmentOrRejection)
```

##### `.finallyEnd(onFulfillmentOrRejection)`

Chains a handler to invoke when the promise is settled (either fulfilled or rejected).

* `onFulfillmentOrRejection`: `Void -> Void`
* returns: `Void`

Conceptual shorthand for:

```haxe
.end(onFulfillmentOrRejection, onFulfillmentOrRejection)
```

##### `.thenFulfilled(value)`

Chains a handler that returns a new fulfilled Promise after the
previous promise is fulfilled.

* `value`: `TValueNext`
* returns: `Promise<TValueNext>`

* Shorthand for:

```haxe
.then(function(_) {
  return Promise.fulfilled(value);
})
```

##### `.thenRejected(reason)`

Chains a handler that returns a new rejected Promise after the previous
promise is fulfilled.

* `reason`: `Reason` - previous promise rejection `Reason`
* returns: `Promise<TValueNext>`

Shorthand for:

```haxe
.catches(function(_) {
  return Promise.rejected(reason);
})
```

##### `.tap(callback)`

Invokes the `callback` for the fulfillment value of the previous promise
then returns the previous promise.

* `callback`: `Void -> Void`
* returns: `Promise<TValue>`

Example:

```haxe
somePromise
  .tap(function(value) {
    // Do something side-effecty with value
    trace(value);
  })
  .then(function(value) {
    // continue on with somePromise's value
  })
  ...
```

##### `.delay(ms)`

Adds a time delay to a promise chain

* `ms`: `Int` - milliseconds to delay
* returns: `Promise<Nil>`

Example:

```haxe
somePromise
  .delay(500)
  .end(function(_) {
    // executed after 500ms delay
  });
```

#### Static helpers

##### `Promise.tries(callback)`

Executes a function and expects the return of a new Promise instance.

Intended to wrap blocks of synchronous code, so that throw exceptions
can be turned into rejected `Promise`s.

* `callback`: `Void -> PromiseOrValue<TValueNext>`
* returns: `Promise<TValueNext>`

Example:

```haxe
Promise.tries(function() {
  // ...do something synchronous that might throw
  // If this throws, the error will be caught and returned as a rejected `Promise`

  // Return a `Promise`...
  return new Promise(function(resolve, reject) {
    // resolve or reject
  });
});
```

##### `Promise.all(inputs)`

Returns a `Promise` that is fulfilled when all the input `Promise`s (or
values) are fulfilled, or rejected if any input `Promise` is rejected.
If fulfilled, the fulfillment value is an `Array<Dynamic>` of values
corresponding to each input `Promise`.  The input array can be a mix of
`Promises` and values, and can be of mixed types.

* `inputs`: `Array<PromiseOrValue<Dynamic>>`
* returns: `Promise<Array<Dynamic>>`

Example:

```haxe
Promise.all(["test1", Promise.fulfilled("test2"), "test3", 3, Promise.fulfilled(4)])
  .end(function(results) {
    // results : Array<Dynamic> == ["test1", "test2", "test3", 3, 4]
  }, function(reason) {
    trace("Something was rejected");
  });
```

##### `Promise.any(inputs)`

Returns a `Promise` that is fulfilled with the value of the first input
promise that is fulfilled, or rejected if all input `Promise`s are rejected.

* `inputs`: `Array<PromiseOrValue<Dynamic>>`
* returns: `Promise<Dynamic>`

Example:

```haxe
Promise.any([Promise.rejected("test1"), "test2"])
  .end(function(result) {
    // result == "test2"
  });
```

##### `Promise.many(inputs, manyCount)`

Returns a Promise that is fulfilled with an array of `manyCount` values
for the first `manyCount` input promises or values that are fulfilled,
or rejected if fewer than `manyCount` input promises are fulfilled.

TODO: not sure if result array should have indices corresponding to
input promises, or if it should be collapsed to remove nulls.

* `inputs`: `Array<PromiseOrValue<Dynamic>>`
* returns: `Promise<Array<Dynamic>>`

Example:

```haxe
Promise.many([Promise.rejected("test1"), "test2", Promise.rejected("test3"), "test4", "test5"], 2)
  .end(function(results) {
    // results[1] == "test2" // TODO: or index 0?
    // results[3] == "test4" // TODO: or index 1?
  });
```

##### `Promise.settled(inputs)`

Returns a `Promise` that is fulfilled when all of the inputs are settled
(fulfilled or rejected).  The fulfillment value is an array of settled
`Promise`s which can be inspected using the `Promise` introspection
methods.

* `inputs`: `Array<PromiseOrValue<Dynamic>>`
* returns: `Array<Promise<Dynamic>>`

Example:

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

Maps an array of `Promise`s or values of the same underlying type to an
array of values of another type.  Inputs are resolved before mapping,
and the mapping function can be asynhronous (return a `Promise`).

* `inputs`: `Array<PromiseOrValue<TValueInput>>`
* `mapper`: `TValueInput -> PromiseOrValue<TValueOutput>`
* returns: `Promise<Array<TValueOutput>>`

Example:

```haxe
var inputs : Array<PromiseOrValue<Int> = [1, Promise.fulfilled(2), 3];

var mapper = function(input : Int) : PromiseOrValue<Int> {
  return Promise.delayed(50)
    .thenFulfilled(input * 2);
};

Promise.map(inputs, mapper)
  .end(function(results) {
    // results == [2, 4, 6]
  });
```

##### `Promise.each(inputs, callback)`

Iterates over an array of input `Promise`s or values, and executes a
side-effect callback for each resolved value.  The callback can be
asynchronous (return `Promise<Nil>`), but cannot change the input value.
This method returns a `Promise` of an array of the resolved input values.

* `inputs`: `Array<PromiseOrValue<TValue>>`
* `callback` TValueInput -> PromiseOrValue<Nil>
* returns: `Promise<Array<TValueInput>>`

Example:

```haxe
var inputs : Array<PromiseOrValue<Int> = [1, 2, 3];

var callback = function(input : Int) : PromiseOrValue<Int> {
  return Promise.delayed(function() {
    trace(input);
  }, 0);
};

Promise.each(inputs, callback)
  .end(function(results) {
    // each callback prints "1\n2\n3"
    // results == [1, 2, 3]
  });
```

##### `Promise.reduce(inputs, reducer, initialValue)`

Reduces an array of input `Promise`s or values into a single value,
using a potentially asynchronous reducer function.

* `inputs`: `Array<PromiseOrValue<TValueInput>>`
* `reducer`: TValueOutput -> TValueInput -> PromiseOrValue<TValueOutput>
* `initialValue`: `TValueOutput` - the initial value of the reduction

Example:

```haxe
var inputs : Array<PromiseOrValue<Int>> = [1, Promise.fulfilled(2), 3];

var reducer = function(acc : String, value : Int) : PromiseOrValue<String> {
  return Promise.delayed(50)
    .thenFulfilled(acc + Std.string(value));
};

var initialValue = "";

Promise.reduce(inputs, reducer, initialValue)
  .end(function(result) {
    // result == "123"
  });
```

##### `Promise.filter(inputs, filterer)`

Filters an array of input `Promise`s or values using a potentially
asynchronous filter function.

* `inputs`: `Array<PromiseOrValue<TValue>>`
* `filterer`: `TValue -> PromiseOrValue<Bool>`
* returns: `Promise<Array<TValue>>` - filtered down using `filterer`

Example:

```haxe
var inputs : Array<PromiseOrValue<Int>> = [1, 2, Promise.fulfilled(3), 4, 5];

var filterer = function(value : Int) : PromiseOrValue<Bool> {
  return Promise.delayed(50)
    .thenFulfilled(value < 4);
};

Promise.filter(inputs, filterer)
  .end(function(results) {
    // results = [1, 2, 3]
  });
```

##### `Promise.delayed(ms)`

Creates a promise that is fulfilled with `Nil.nil` after a `ms` time delay.

* `ms`: `Int` - millisecond delay

Example:

```haxe
Promise.delayed(500)
  .end(function(_) {
    // executed after 500ms delay
  });
```

#### Promise introspection

##### `.isPending()`

Indicates if a `Promise` is pending

* returns: `Bool`

##### `.isFulfilled()`

Indicates if a `Promise` is fulfilled

* returns: `Bool`

##### `.isRejected()`

Indicates if a `Promise` is rejected

* returns: `Bool`

##### `.isSettled()`

Indicates if a `Promise` is settled (fulfilled or rejected)

* returns: `Bool`

##### `.getValue()`

Gets the value of a fulfilled `Promise`

* returns: `TValue`

##### `.getReason()`

Gets the reason of a rejected `Promise`

* returns: `Reason`
