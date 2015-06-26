package redhawk;

import haxe.Timer;

class Promise<TValue> {
  public static var UNHANDLED_REJECTION_EVENT(default, null) : String;
  public static var events(default, null) : Events;
  public static var defer(default, default) : (Void -> Void) -> Int -> Void;
  public static var nextTick(default, default) : (Void -> Void) -> Void;
  static var idCounter(default, null) : Int;

  public var id(default, null) : Int;
  public var name(default, null) : String;
  public var state(default, null) : State<TValue>;

  var fulfillmentListeners(default, null) : Array<TValue -> Void>;
  var rejectionListeners(default, null) : Array<Reason -> Void>;
  var hasListeners(default, null) : Bool;

  public static function __init__() {
    UNHANDLED_REJECTION_EVENT = "unhandled:rejection";
    events = new Events();
    events.on(UNHANDLED_REJECTION_EVENT, function(reason : Reason) {
      trace("unhandled rejection");
    });
    defer = Timer.delay;
    nextTick = Timer.delay.bind(_, 0);
    idCounter = 0;
  }

  public function new(resolver : ((TValue -> Void) -> (Reason -> Void) -> Void), ?name : String) {
    this.id = nextId();
    this.name = (name != null && name.length > 0) ? 'Promise: $name' : 'Promise: $id';
    this.state = Pending;
    this.fulfillmentListeners = [];
    this.rejectionListeners = [];
    this.hasListeners = false;

    try {
      resolver(setFulfilled, setRejected);
    } catch (reason : Reason) {
      setRejected(reason);
    } catch (e : Dynamic) {
      setRejected(e);
    }
  }

  public function then<TValueNext>(
      ?onFulfillment : TValue -> PromiseOrValue<TValueNext>,
      ?onRejection : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    hasListeners = true;
    return new Promise(function(resolveNext : TValueNext -> Void, rejectNext : Reason -> Void) {
      switch state {
        case Pending:
          addFulfillmentListener(onFulfillment, resolveNext, rejectNext);
          addRejectionListener(onRejection, resolveNext, rejectNext);
        case Fulfilled(value):
          addFulfillmentListener(onFulfillment, resolveNext, rejectNext);
          notifyOnNextTick();
        case Rejected(reason):
          addRejectionListener(onRejection, resolveNext, rejectNext);
          notifyOnNextTick();
      };
    });
  }

  public function thenv(?onFulfillment : TValue -> Void, ?onRejection : Reason -> Void) : Promise<Nil> {
    var wrappedOnFulfillment : TValue -> PromiseOrValue<Nil> = null;
    var wrappedOnRejection : Reason -> PromiseOrValue<Nil> = null;

    if (onFulfillment != null) {
      wrappedOnFulfillment = function(value) {
        return new Promise(function(resolve, reject) {
          onFulfillment(value);
          resolve(Nil.nil);
        });
      };
    }

    if (onRejection != null) {
      wrappedOnRejection = function(reason) {
        return new Promise(function(resolve, reject) {
          onRejection(reason);
          resolve(Nil.nil); // Resolve this to nil unless onRejection throws - this way the rejection is "handled"
        });
      };
    }

    return then(wrappedOnFulfillment, wrappedOnRejection);
  }

  public function catches<TValueNext>(
      onRejection : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    return then(null, onRejection);
  }

  public function catchesv(onRejection : Reason -> Void) : Promise<Nil> {
    return thenv(null, onRejection);
  }

  public function finally(onFulfillmentOrRejection : Void -> Void) : Promise<TValue> {
    return then(function(value) {
      onFulfillmentOrRejection();
      return this;
    }, function(reason) {
      onFulfillmentOrRejection();
      return this;
    });
  }

  public function thenFulfilled<TValueNext>(value : TValueNext) : Promise<TValueNext> {
    return then(function(_) {
      return Promise.fulfilled(value);
    });
  }

  public function thenRejected<TValueNext>(reason : Reason) : Promise<TValueNext> {
    return then(function(_) {
      return Promise.rejected(reason);
    });
  }

  public function tap(callback : TValue -> Void) : Promise<TValue> {
    return then(function(value) {
      callback(value);
      return this;
    });
  }

  public function delay(ms : Int) : Promise<Nil> {
    return then(function(value) {
      return Promise.delayed(ms);
    });
  }

  public static function fulfilled<TValue>(value : TValue) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      resolve(value);
    });
  }

  public static function rejected<TValue>(reason : Reason) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      reject(reason);
    });
  }

  public static function tries<TValue>(callback : Void -> PromiseOrValue<TValue>) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      try {
        callback()
          .toPromise()
          .thenv(resolve, reject);
      } catch (reason : Reason) {
        reject(reason);
      } catch (e : Dynamic) {
        reject(e);
      }
    });
  }

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
          throw new Reason('Promise.all: null inputs not allowed');
        }
        inputs[i]
          .toPromise()
          .thenv(function(value) {
            fulfillmentCount++;
            if (!isSettled) {
              fulfillments[i] = value;
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
          throw new Reason('Promise.any: null inputs not allowed');
        }
        inputs[i]
          .toPromise()
          .thenv(function(value) {
            fulfillmentCount++;
            if (!isSettled) {
              fulfillment = value;
              isSettled = true;
              resolve(fulfillment);
            }
          }, function(reason) {
            rejectionCount++;
            if (!isSettled) {
              rejections[i] = reason;
              if (rejectionCount == totalCount) {
                isSettled = true;
                reject(rejections);
              }
            }
          });
      }
    });
  }

  public static function many(inputs : Array<PromiseOrValue<Dynamic>>, manyCount : Int) {
    return new Promise(function(resolve, reject) {
      if (manyCount <= 0) {
        throw new Reason('Promise.many: manyCount must be greater than 0');
      }
      var totalCount = inputs.length;
      var isSettled = false;
      var fulfillmentCount = 0;
      var rejectionCount = 0;
      var fulfillments : Array<Dynamic> = [];
      var rejections : Array<Reason> = [];

      for (i in 0...totalCount) {
        if (inputs[i] == null) {
          throw new Reason('Promise.many: null values not allowed');
        }
        inputs[i]
          .toPromise()
          .thenv(function(value) {
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
          throw new Reason('Promise.settled: null inputs not allowed');
        }
        var promise = inputs[i].toPromise();
        promise.finally(function() {
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
          throw new Reason('Promise.map: null inputs not allowed');
        }

        inputs[i]
          .toPromise()
          .then(function(inputValue) {
            return mapper(inputValue);
          })
          .thenv(function(outputValue) {
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
          throw new Reason('Promise.each: null inputs not allowed');
        }
        var inputValue : TValue = null;
        inputs[i]
          .toPromise()
          .then(function(value) {
            inputValue = value;
            return callback(inputValue);
          })
          .thenv(function(_) {
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
          throw new Reason('Promise.filter: null inputs not allowed');
        }

        var inputValue : TValue = null;
        inputs[i]
          .toPromise()
          .then(function(value) {
            inputValue = value;
            return filterer(value);
          })
          .thenv(function(keep) {
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
      defer(function() {
        resolve(Nil.nil);
      }, ms);
    });
  }

  public static function nil() : Promise<Nil> {
    return new Promise(function(resolve, reject) {
      resolve(Nil.nil);
    });
  }

  public static function on(name : String, callback : Dynamic -> Void) {
    events.on(name, callback);
  }

  public static function once(name : String, callback : Dynamic -> Void) {
    events.once(name, callback);
  }

  public static function off(name : String, ?callback : Dynamic -> Void) {
    events.off(name, callback);
  }

  public static function emit(name : String, ?data : Dynamic) {
    events.emit(name, data);
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
      case _: throw new Reason("Cannot get value for unfulfilled promise");
    };
  }

  public function getReason() : Reason {
    return switch state {
      case Rejected(reason) : reason;
      case _: throw new Reason("Cannot get reason for non-rejected promise");
    };
  }

  public function toString() : String {
    return name;
  }

  function setFulfilled(value : TValue) : Void {
    switch state {
      case Pending:
        state = Fulfilled(value);
        notifyOnNextTick();
      case other:
        throw new Reason('Promise cannot change from $other to Fulfilled');
    }
  }

  function setRejected(reason : Reason) : Void {
    switch state {
      case Pending:
        state = Rejected(reason);
        notifyOnNextTick();
        checkUnhandledRejectionOnNextTick(reason);
      case other:
        throw new Reason('Promise cannot change from $other to Rejected');
    }
  }

  function checkUnhandledRejectionOnNextTick(reason : Reason) : Void {
    if (!hasListeners) {
      nextTick(function() {
        if (!hasListeners) {
          emit(UNHANDLED_REJECTION_EVENT, reason);
        }
      });
    }
  }

  function addFulfillmentListener<TValueNext>(
      ?onFulfillment : TValue -> PromiseOrValue<TValueNext>,
      resolveNext : TValueNext -> Void,
      rejectNext : Reason -> Void) : Void {

    if (onFulfillment == null) {
      // If there is no fulfillment handler, we can't pass the current TValue along, because its expecting
      // a TValueNext.
      return;
    }

    fulfillmentListeners.push(function(value) {
      try {
        onFulfillment(value)
          .toPromise()
          .thenv(resolveNext, rejectNext);
      } catch (reason : Reason) {
        rejectNext(reason);
      } catch (e : Dynamic) {
        rejectNext(e);
      }
    });
  }

  function addRejectionListener<TValueNext>(
      ?onRejection : Reason -> PromiseOrValue<TValueNext>,
      resolveNext : TValueNext -> Void,
      rejectNext : Reason -> Void) : Void {
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
          .thenv(resolveNext, rejectNext);
      } catch (reason : Reason) {
        rejectNext(reason);
      } catch (e : Dynamic) {
        rejectNext(e);
      }
    });
  }

  function notifyOnNextTick() : Void {
    nextTick(function() {
      switch state {
        case Fulfilled(value):
          for (fulfillmentListener in fulfillmentListeners) {
            fulfillmentListener(value);
          }
          fulfillmentListeners = [];

        case Rejected(reason):
          for (rejectionListener in rejectionListeners) {
            rejectionListener(reason);
          }
          rejectionListeners = [];

        case _: // No-op
      }
    });
  }

  static function nextId() : Int {
    return idCounter++;
  }

  inline function debug() {
    untyped __js__("debugger;");
  }
}
