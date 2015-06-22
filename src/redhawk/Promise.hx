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
    switch state {
      case Pending:
        return new Promise(function(resolveNext : TValueNext -> Void, rejectNext : Reason -> Void) {
          addFulfillmentListener(onFulfillment, resolveNext, rejectNext);
          addRejectionListener(onRejection, resolveNext, rejectNext);
        });
      case Fulfilled(value):
        return new Promise(function(resolveNext : TValueNext -> Void, rejectNext : Reason -> Void) {
          addFulfillmentListener(onFulfillment, resolveNext, rejectNext, true);
        });
      case Rejected(reason):
        return new Promise(function(resolveNext : TValueNext -> Void, rejectNext : Reason -> Void) {
          addRejectionListener(onRejection, resolveNext, rejectNext, true);
        });
    };
  }

  /**
   * Chains fulfillment/rejection handlers onto this promise.  The fulfillment/rejection
   * handlers in `end` cannot return a value nor promise, so the promise chain will end here
   */
  public function end(?onFulfillment : TValue -> Void, ?onRejection : Reason -> Void) : Promise<TValue> {
    switch state {
      case Pending:
        addFulfillmentListenerEnd(onFulfillment);
        addRejectionListenerEnd(onRejection);
      case Fulfilled(value):
        addFulfillmentListenerEnd(onFulfillment, true);
      case Rejected(reason):
        addRejectionListenerEnd(onRejection, true);
    };
    return this;
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
  public function catchesEnd(onRejection : Reason -> Void) : Promise<TValue> {
    end(null, onRejection);
    return this;
  }

  /**
   * Chains a handler to be called when this promise is either fulfilled or rejected.
   */
  public function finally(onFinally : Void -> Void) : Promise<TValue> {
    end(function(value) {
      onFinally();
    }, function(reason) {
      onFinally();
    });
    return this;
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

  function addFulfillmentListenerEnd(?onFulfillment : TValue -> Void, ?notify : Bool = false) {
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

  function addRejectionListenerEnd(?onRejection : Reason -> Void, ?notify : Bool = false) {
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

  static function nextId() {
    return idCounter++;
  }
}
