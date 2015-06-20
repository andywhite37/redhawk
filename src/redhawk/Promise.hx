package redhawk;

import haxe.Timer;

class Promise<TValue> {
  static var idCounter(default, null) : Int = 0;
  public var id(default, null) : Int;
  public var name(default, null) : String;
  public var state(default, null) : State<TValue>;
  var fulfillmentListeners(default, null) : Array<TValue -> Void>;
  var rejectionListeners(default, null) : Array<Reason -> Void>;

  public function new(?name : String, resolver : ((TValue -> Void) -> (Reason -> Void) -> Void)) {
    this.id = nextId();
    this.name = name != null ? 'Promise: $name' : 'Promise: $id';
    this.state = Pending;
    this.fulfillmentListeners = [];
    this.rejectionListeners = [];

    try {
      resolver(setFulfilled, setRejected);
    } catch (e : Dynamic) {
      setRejected(new Reason(e));
    }
  }

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

  public function end(?onFulfillment : TValue -> Void, ?onRejection : Reason -> Void) {
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

  public function catches<TValueNext>(
      onRejected : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    return then(null, onRejected);
  }

  public function catchesEnd(onRejected : Reason -> Void) : Void {
    end(null, onRejected);
  }

  public static function tries<TValue>(callback : Void -> PromiseOrValue<TValue>) {
    return new Promise(function(resolve, reject) {
      try {
        callback()
          .toPromise()
          .end(resolve, reject);
      } catch (e : Dynamic) {
        reject(new Reason(e));
      }
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

  public function toString() {
    return name;
  }

  function setFulfilled(value : TValue) {
    switch state {
      case Pending:
        state = Fulfilled(value);
        notify();
      case other:
        throw new js.Error('Promise cannot change from $other to Fulfilled');
    }
  }

  function setRejected(reason : Reason) {
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
      ?notify : Bool = false) {
    if (onFulfillment == null) {
      return;
    }

    fulfillmentListeners.push(function(value) {
      onFulfillment(value)
        .toPromise()
        .end(function(valueNext) {
          resolveNext(valueNext);
        }, function(reasonNext) {
          rejectNext(reasonNext);
        });
    });

    if (notify) {
      this.notify();
    }
  }

  function addRejectionListener<TValueNext>(
      ?onRejection : Reason -> PromiseOrValue<TValueNext>,
      resolveNext : TValueNext -> Void,
      rejectNext : Reason -> Void,
      ?notify : Bool = false) {
    if (onRejection == null) {
      return;
    }
    rejectionListeners.push(function(value) {
      onRejection(value)
        .toPromise()
        .end(function(valueNext) {
          resolveNext(valueNext);
        }, function(reasonNext) {
          rejectNext(reasonNext);
        });
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
          trace('Notifying ${rejectionListeners.length} rejection listeners');
          for (rejectionListener in rejectionListeners) {
            rejectionListener(reason);
          }
          rejectionListeners = [];
        }, 0);
      case _:
    }
  }

  static function nextId() {
    return idCounter++;
  }
}
