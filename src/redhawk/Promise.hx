package redhawk;

class Promise<TValue> {
  static var idCounter(default, null) : Int = 0;
  var id(default, null) : Int;
  var state(default, null) : State<TValue>;
  var fulfillmentListeners(default, null) : Array<TValue -> Void>;
  var rejectionListeners(default, null) : Array<Reason -> Void>;

  public function new(resolver : ((TValue -> Void) -> (Reason -> Void) -> Void)) {
    id = nextId();
    state = Pending;
    fulfillmentListeners = [];
    rejectionListeners = [];

    try {
      resolver(setFulfilled, setRejected);
    } catch (e : Dynamic) {
      setRejected(new Reason("Caught error in promise resolver", e));
    }
  }

  public function then<TValueNext>(
    ?onFulfillment : TValue -> PromiseOrValue<TValueNext>,
    ?onRejection : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    switch state {
      case Pending:
        trace('then $id Pending');
        return new Promise(function(resolve : TValueNext -> Void, reject : Reason -> Void) {
          if (onFulfillment != null) {
            fulfillmentListeners.push(function(value) {
              onFulfillment(value)
                .toPromise()
                .end(function(valueNext) {
                  resolve(valueNext);
                }, function(reasonNext) {
                  reject(reasonNext);
                });
            });
          }
          if (onRejection != null) {
            rejectionListeners.push(function(reason) {
              onRejection(reason)
                .toPromise()
                .end(function(valueNext) {
                  resolve(valueNext);
                }, function(reasonNext) {
                  reject(reasonNext);
                });
            });
          }
        });

      case Fulfilled(value):
        trace('then $id Fulfilled($value)');
        return new Promise(function(resolve : TValueNext -> Void, reject : Reason -> Void) {
          if (onFulfillment != null) {
            fulfillmentListeners.push(function(value) {
              onFulfillment(value)
                .toPromise()
                .end(function(valueNext) {
                  resolve(valueNext);
                }, function(reasonNext) {
                  reject(reasonNext);
                });
            });
            notify();
          }
        });

      case Rejected(reason):
        trace('then $id Rejected($reason)');
        return new Promise(function(resolve : TValueNext -> Void, reject : Reason -> Void) {
          if (onRejection != null) {
            rejectionListeners.push(function(reason) {
              onRejection(reason)
                .toPromise()
                .end(function(valueNext : TValueNext) {
                  resolve(valueNext);
                }, function(reasonNext : Reason) {
                  reject(reasonNext);
                });
            });
            notify();
          }
        });
    };
  }

  public function end(?onFulfillment : TValue -> Void, ?onRejection : Reason -> Void) {
    switch state {
      case Pending:
        trace('end $id Pending');
        if (onFulfillment != null) {
          fulfillmentListeners.push(function(value) {
            onFulfillment(value);
          });
        }
        if (onRejection != null) {
          rejectionListeners.push(function(reason) {
            onRejection(reason);
          });
        }
      case Fulfilled(value):
        trace('end $id Fulfilled($value)');
        if (onFulfillment != null) {
          fulfillmentListeners.push(function(value) {
            onFulfillment(value);
          });
          notify();
        }
      case Rejected(reason):
        trace('end $id Rejected($reason)');
        if (onRejection != null) {
          rejectionListeners.push(function(reason) {
            onRejection(reason);
          });
          notify();
        }
    };
  }

  public function catches<TValueNext>(onRejected : Reason -> PromiseOrValue<TValueNext>) : Promise<TValueNext> {
    return then(null, onRejected);
  }

  public static function tries<TValue>(callback : Void -> PromiseOrValue<TValue>) {
    return new Promise(function(resolve, reject) {
      try {
        resolve(callback());
      } catch (e : Dynamic) {
        reject(new Reason("Caught error in tries", e));
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

  function setFulfilled(value : TValue) {
    trace('Promise $id fulfilled with value: $value');
    switch state {
      case Pending:
        state = Fulfilled(value);
        notify();
      case other:
        throw new js.Error('Promise cannot change from $other to Fulfilled');
    }
  }

  function setRejected(reason : Reason) {
    trace('Promise $id rejected with reason: $reason');
    switch state {
      case Pending:
        state = Rejected(reason);
        notify();
      case other:
        throw new js.Error('Promise cannot change from $other to Fulfilled');
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
      case _:
    }
  }

  static function nextId() {
    return idCounter++;
  }
}
