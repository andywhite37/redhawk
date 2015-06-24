package redhawk;

import haxe.Timer;

class Promise<TValue> {
  /**
   * Private counter of unique ids for promise instances
   */
  static var idCounter(default, null) : Int = 0;

  /**
   * Unique identifier for this Promise
   */
  public var id(default, null) : Int;

  /**
   * User-specified name for this Promise (does not need to be unique)
   */
  public var name(default, null) : String;

  /**
   * Current State of this promise.
   */
  public var state(default, null) : State<TValue>;

  /**
   * List of listeners to be notified when this promise is fulfilled
   */
  var fulfillmentListeners(default, null) : Array<TValue -> Void>;

  /**
   * List of listeners to be notified when this promise is rejected
   */
  var rejectionListeners(default, null) : Array<Reason -> Void>;

  /**
   * Constructor for a Promise.
   */
  public function new(?name : String, resolver : ((TValue -> Void) -> (Reason -> Void) -> Void)) {
    this.id = nextId();
    this.name = (name != null && name.length > 0) ? 'Promise: $name' : 'Promise: $id';
    this.state = Pending;
    this.fulfillmentListeners = [];
    this.rejectionListeners = [];

    try {
      resolver(setFulfilled, setRejected);
    } catch (e : Dynamic) {
      setRejected(e);
    }
  }

  /**
   * Chains fulfillment/rejection handlers onto this promise.  The fulfillment/rejection
   * handlers should return either a value or a new promise.  If you don't want to return
   * a value or promise, use the `end` function instead.
   */
  public function then<TValueNext>(
      ?onFulfillment : TValue -> PromiseOrValue<TValueNext>,
      ?onRejection : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    return new Promise(function(resolveNext : TValueNext -> Void, rejectNext : Reason -> Void) {
      switch state {
        case Pending:
          addFulfillmentListener(onFulfillment, resolveNext, rejectNext);
          addRejectionListener(onRejection, resolveNext, rejectNext);
        case Fulfilled(value):
          addFulfillmentListener(onFulfillment, resolveNext, rejectNext, true);
        case Rejected(reason):
          addRejectionListener(onRejection, resolveNext, rejectNext, true);
      };
    });
  }

  /**
   * Chains fulfillment/rejection handlers onto this promise.  The fulfillment/rejection
   * handlers in `end` cannot return a new value nor promise.
   */
  public function end(?onFulfillment : TValue -> Void, ?onRejection : Reason -> Void) : Void {
    switch state {
      case Pending:
        addFulfillmentListenerEnd(onFulfillment);
        addRejectionListenerEnd(onRejection);
      case Fulfilled(value):
        addFulfillmentListenerEnd(onFulfillment, true);
      case Rejected(reason):
        addRejectionListenerEnd(onRejection, true);
    };
  }

  /**
   * Chains a rejection handler onto this promise.  Shortcut for `.then(null, onRejection)`.
   * The rejection handler should return a new value or promise.  If you don't want to return
   * a value or promise, use `catchesEnd` instead.
   */
  public function catches<TValueNext>(
      onRejection : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    return then(null, onRejection);
  }

  /**
   * Chains a rejection handler onto this promise.  Shortcut for `.end(null, onRejection)`.
   * The rejection handler cannot return a value nor promise, so the promise chain will end here.
   */
  public function catchesEnd(onRejection : Reason -> Void) : Void {
    end(null, onRejection);
  }

  /**
   * Chains a handler to be called when this promise is either fulfilled or rejected.
   * The always callback can return a new Promise or value to continue the chain.
   * Returns this Promise when the finally function is settled.
   */
  public function finally(onFulfillmentOrRejection : Void -> Void) : Promise<TValue> {
    return then(function(value) {
      onFulfillmentOrRejection();
      return this;
    }, function(reason) {
      onFulfillmentOrRejection();
      return this;
    });
  }

  /**
   * Chains a handler to be called when this Promise is either fulfilled or rejected.
   * The handler cannot return a new Promise nor value.
   */
  public function finallyEnd(onFulfillmentOrRejection : Void -> Void) : Void {
    end(function(value) {
      onFulfillmentOrRejection();
    }, function(reason) {
      onFulfillmentOrRejection();
    });
  }

  /**
   * Returns a new fulfilled Promise for the given value after this Promise is resolved.
   */
  public function thenFulfilled<TValueNext>(value : TValueNext) : Promise<TValueNext> {
    return then(function(_) {
      return value;
    });
  }

  /**
   * Returns a new rejected Promise for the given reason after this Promise is resolved.
   */
  public function thenRejected<TValueNext>(reason : Reason) : Promise<TValueNext> {
    return then(function(_) {
      return Promise.rejected(reason);
    });
  }

  /**
   * Adds an interceptor callback into a promise chain, so the current value can be inspected.
   * Returns the previous promise unchanged.
   */
  public function tap(callback : TValue -> Void) : Promise<TValue> {
    return then(function(value) {
      callback(value);
      return this;
    });
  }

  /**
   * Returns a promise that is delayed by `ms`.
   */
  public function delay(ms : Int) : Promise<Nil> {
    return then(function(value) {
      return Promise.delayed(ms);
    });
  }

  /**
   * Helper method which returns a promise that is fulfilled with the given value.
   */
  public static function fulfilled<TValue>(value : TValue) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      resolve(value);
    });
  }

  /**
   * Helper method which returns a promise that is rejected with the given reason.
   */
  public static function rejected<TValue>(reason : Reason) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      reject(reason);
    });
  }

  /**
   * Returns a new promise which executes the callback in a try/catch, so that thrown errors
   * can be turned into rejections.
   */
  public static function tries<TValue>(callback : Void -> PromiseOrValue<TValue>) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      try {
        callback()
          .toPromise()
          .end(resolve, reject);
      } catch (e : Dynamic) {
        reject(e);
      }
    });
  }

  /**
   * Returns a Promise that is fulfilled with an array of results corresponding to the fulfillment value
   * of each input.
   * If any input Promise is rejected, the returned Promise is rejected with the input's rejection Reason.
   */
  public static function all(inputs : Array<PromiseOrValue<Dynamic>>) : Promise<Array<Dynamic>> {
    var totalCount = inputs.length;
    var isSettled = false;
    var fulfillmentCount = 0;
    var rejectionCount = 0;
    var fulfillments : Array<Dynamic> = [];
    var rejections : Array<Reason> = [];

    return new Promise(function(resolve, reject) {
      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.all: null inputs not allowed';
        }
        inputs[i]
          .toPromise()
          .end(function(value) {
            fulfillmentCount++;
            if (!isSettled) {
              fulfillments[i] = value;
              if (fulfillmentCount == totalCount) {
                // Got all fulfillments, resolve main promise
                isSettled = true;
                resolve(fulfillments);
              }
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              // Got a rejection, reject main promise
              rejections[i] = reason;
              isSettled = true;
              reject(rejections);
            }
          });
      }
    });
  }

  /**
   * Returns a Promise that is fulfilled with the fulfillment value of the first input promise to be fulfilled.
   * If all input promises are rejected, the returned Promise will be rejected.
   */
  public static function any(inputs : Array<PromiseOrValue<Dynamic>>) : Promise<Dynamic> {
    return new Promise(function(resolve, reject) {
      var totalCount = inputs.length;
      var isSettled = false;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var fulfillment : Dynamic = null;
      var rejections : Array<Reason> = [];

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.any: null inputs not allowed';
        }
        inputs[i]
          .toPromise()
          .end(function(value) {
            fulfillmentCount++;
            if (!isSettled) {
              // Got a fulfillment, resolve the main promise now
              fulfillment = value;
              isSettled = true;
              resolve(fulfillment);
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              if (rejectionCount == totalCount) {
                // Did not get any fulfillments, reject
                isSettled = true;
                reject(rejections);
              }
            }
          });
      }
    });
  }

  /**
   * Returns a Promise that is fulfilled with an array of fulfillment values for the first `manyCount`
   * input promises to be fulfilled.
   * If fewer than `manyCount` input promises are fulfilled, the returned promise will be rejected.
   */
  public static function many(inputs : Array<PromiseOrValue<Dynamic>>, manyCount : Int) {
    return new Promise(function(resolve, reject) {
      if (manyCount <= 0) {
        throw 'Promise.many: manyCount must be greater than 0';
      }
      var totalCount = inputs.length;
      var isSettled = false;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var fulfillments : Array<Dynamic> = [];
      var rejections : Array<Reason> = [];

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.many: null values not allowed';
        }
        inputs[i]
          .toPromise()
          .end(function(value) {
            fulfillmentCount++;
            if (!isSettled) {
              fulfillments[i] = value;
              if (fulfillmentCount == manyCount) {
                // Got enough fulfillments, resolve
                isSettled = true;
                resolve(fulfillments);
              } else if (fulfillmentCount + rejectionCount == totalCount) {
                // Did not get enough fulfillments, reject
                isSettled = true;
                reject(rejections);
              }
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              if (fulfillmentCount + rejectionCount == totalCount) {
                // Did not get enough fulfillments, reject
                isSettled = true;
                reject(rejections);
              }
            }
          });
      }
    });
  }

  public static function settled(inputs : Array<PromiseOrValue<Dynamic>>) : Promise<Array<Promise<Dynamic>>> {
    return new Promise(function(resolve, reject) {
      var totalCount = inputs.length;
      var settledCount = 0;
      var promises : Array<Promise<Dynamic>> = [];

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.settled: null inputs not allowed';
        }
        var promise = inputs[i].toPromise();
        promise.finallyEnd(function() {
          settledCount++;
          promises[i] = promise;
          if (settledCount == totalCount) {
            resolve(promises);
          }
        });
      }
    });
  }

  public static function map<TValueInput, TValueOutput>(
      inputs : Array<PromiseOrValue<TValueInput>>,
      mapper : TValueInput -> PromiseOrValue<TValueOutput>) : Promise<Array<TValueOutput>> {
    return new Promise(function(resolve, reject) {
      var totalCount = inputs.length;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var isSettled = false;
      var fulfillments : Array<TValueOutput> = [];
      var rejections : Array<Reason> = [];

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.map: null inputs not allowed';
        }

        // Resolve the input value
        inputs[i]
          .toPromise()
          .then(function(inputValue) {
            // Map the input value into the output value and resolve
            return mapper(inputValue);
          })
          .end(function(outputValue) {
            fulfillmentCount++;
            if (!isSettled) {
              fulfillments[i] = outputValue;
              if (fulfillmentCount == totalCount) {
                isSettled = true;
                resolve(fulfillments);
              }
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              isSettled = true;
              reject(rejections);
            }
          });
      }
    });
  }

  public static function each<TValue>(
      inputs : Array<PromiseOrValue<TValue>>,
      callback : TValue -> PromiseOrValue<Nil>) : Promise<Array<TValue>> {
    return new Promise(function(resolve, reject) {
      var totalCount = inputs.length;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var isSettled = false;
      var fulfillments : Array<TValue> = [];
      var rejections = [];

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.each: null inputs not allowed';
        }
        var inputValue : TValue = null;
        inputs[i]
          .toPromise()
          .then(function(value) {
            inputValue = value;
            return callback(inputValue);
          })
          .end(function(_) {
            fulfillmentCount++;
            if (!isSettled) { 
              fulfillments[i] = inputValue;
              if (fulfillmentCount == totalCount) {
                isSettled = true;
                resolve(fulfillments);
              }
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              isSettled = true;
              reject(rejections);
            }
          });
      }
    });
  }

  public static function reduce<TValueInput, TValueOutput>(
      inputs: Array<PromiseOrValue<TValueInput>>,
      reducer: TValueOutput -> TValueInput -> PromiseOrValue<TValueOutput>,
      initialValue : TValueOutput) : Promise<TValueOutput> {
    return new Promise(function(resolve, reject) {
      var totalCount = inputs.length;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var isSettled = false;
      var fulfillment : TValueOutput = initialValue;
      var rejections : Array<Reason> = [];

      if (inputs.length == 0) {
        resolve(fulfillment);
        return;
      }

      var nextFulfillment = Promise.fulfilled(fulfillment);

      for (i in 0...totalCount) {
        nextFulfillment = nextFulfillment
          .then(function(value) {
            fulfillment = value;
            return inputs[i];
          })
          .then(function(inputValue) {
            return reducer(fulfillment, inputValue);
          })
          .then(function(value) {
            fulfillmentCount++;
            if (!isSettled) {
              if (fulfillmentCount == totalCount) {
                isSettled = true;
                resolve(value);
              }
            }
            return value;
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              isSettled = true;
              reject(rejections);
            }
            return Promise.rejected(rejections);
          });
      }
    });
  }

  public static function filter<TValue>(
      inputs: Array<PromiseOrValue<TValue>>,
      filterer: TValue -> PromiseOrValue<Bool>) : Promise<Array<TValue>> {
    return new Promise(function(resolve, reject) {
      var totalCount = inputs.length;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var isSettled = false;
      var fulfillments : Array<TValue> = [];
      var rejections : Array<Reason> = [];

      if (totalCount == 0) {
        resolve([]);
        return;
      }

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw 'Promise.filter: null inputs not allowed';
        }

        var inputValue : TValue = null;

        inputs[i]
          .toPromise()
          .then(function(value) {
            inputValue = value;
            return filterer(value);
          })
          .end(function(keep) {
            fulfillmentCount++;
            if (!isSettled) {
              if (keep) {
                fulfillments.push(inputValue);
              }
              if (fulfillmentCount == totalCount) {
                isSettled = true;
                resolve(fulfillments);
              }
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              isSettled = true;
              reject(rejections);
            }
          });
      }
    });
  }

  public static function delayed(ms : Int) : Promise<Nil> {
    return new Promise(function(resolve, reject) {
      Timer.delay(function() {
        resolve(Nil.nil);
      }, ms);
    });
  }

  public function isPending() : Bool {
    return switch state {
      case Pending: true;
      case _: false;
    };
  }

  public function isFulfilled() : Bool {
    return switch state {
      case Fulfilled(value) : true;
      case _: false;
    };
  }

  public function isRejected() : Bool {
    return switch state {
      case Rejected(reason) : true;
      case _: false;
    };
  }

  public function isSettled() : Bool {
    return switch state {
      case Pending: false;
      case _: true;
    };
  }

  public function getValue() : TValue {
    return switch state {
      case Fulfilled(value): value;
      case _: throw "Cannot get value for unfulfilled promise";
    };
  }

  public function getReason() : Reason {
    return switch state {
      case Rejected(reason) : reason;
      case _: throw "Cannot get reason for non-rejected promise";
    };
  }

  public function toString() : String {
    return name;
  }

  function setFulfilled(value : TValue) : Void {
    switch state {
      case Pending:
        state = Fulfilled(value);
        notify();
      case other:
        throw new js.Error('Promise cannot change from $other to Fulfilled');
    }
  }

  function setRejected(reason : Reason) : Void {
    switch state {
      case Pending:
        state = Rejected(reason);
        notify();
      case other:
        throw new js.Error('Promise cannot change from $other to Rejected');
    }
  }

  function addFulfillmentListener<TValueNext>(
      ?onFulfillment : TValue -> PromiseOrValue<TValueNext>,
      resolveNext : TValueNext -> Void,
      rejectNext : Reason -> Void,
      ?notify : Bool = false) : Void {
    if (onFulfillment == null) {
      // If there is no fulfillment handler, we can't pass the current TValue along, because its expecting
      // a TValueNext.
      return;
    }

    fulfillmentListeners.push(function(value) {
      try {
        onFulfillment(value)
          .toPromise()
          .end(function(valueNext) {
            resolveNext(valueNext);
          }, function(reasonNext) {
            rejectNext(reasonNext);
          });
      } catch (e : Dynamic) {
        rejectNext(e);
      }
    });

    if (notify) {
      this.notify();
    }
  }

  function addRejectionListener<TValueNext>(
      ?onRejection : Reason -> PromiseOrValue<TValueNext>,
      resolveNext : TValueNext -> Void,
      rejectNext : Reason -> Void,
      ?notify : Bool = false) : Void {
    // If there is no rejection handler, create a handler that just passes the rejection reason
    // along.  This allows the error to cascade through a promise chain until it is handled.
    if (onRejection == null) {
      onRejection = function(reason) {
        return Promise.rejected(reason);
      };
    }

    rejectionListeners.push(function(value) {
      try {
        onRejection(value)
          .toPromise()
          .end(function(valueNext) {
            resolveNext(valueNext);
          }, function(reasonNext) {
            rejectNext(reasonNext);
          });
      } catch (e : Dynamic) {
        rejectNext(e);
      }
    });

    if (notify) {
      this.notify();
    }
  }

  function addFulfillmentListenerEnd(?onFulfillment : TValue -> Void, ?notify : Bool = false) : Void {
    if (onFulfillment == null) {
      return;
    }

    fulfillmentListeners.push(function(value) {
      onFulfillment(value);
    });

    if (notify) {
      this.notify();
    }
  }

  function addRejectionListenerEnd(?onRejection : Reason -> Void, ?notify : Bool = false) : Void {
    if (onRejection == null) {
      return;
    }

    rejectionListeners.push(function(reason) {
      onRejection(reason);
    });

    if (notify) {
      this.notify();
    }
  }

  function notify() : Void {
    switch state {
      case Fulfilled(value):
        haxe.Timer.delay(function() {
          for (fulfillmentListener in fulfillmentListeners) {
            fulfillmentListener(value);
          }
          fulfillmentListeners = [];
        }, 0);

      case Rejected(reason):
        haxe.Timer.delay(function() {
          for (rejectionListener in rejectionListeners) {
            rejectionListener(reason);
          }
          rejectionListeners = [];
        }, 0);

      case _: // No-op
    }
  }

  static function nextId() : Int {
    return idCounter++;
  }
}
