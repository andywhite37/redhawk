package redhawk;

class Promise<TValue> {
  var state(default, null) : State<TValue>;
  var fulfillmentListeners(default, null) : Array<TValue -> Void>;
  var rejectionListeners(default, null) : Array<Reason -> Void>;

  public function new(resolver : ((TValue -> Void) -> (Reason -> Void) -> Void)) {
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
    ?onRejection : Reason -> PromiseOrValue<TValueNext>) :
    Promise<TValueNext> {

    switch state {
      case Pending:
        return new Promise(function(resolve : TValueNext -> Void, reject : Reason -> Void) {
          if (onFulfillment != null) {
            fulfillmentListeners.push(function(value) {
              //onFulfillment(value).toPromise().then
            });
          }
          if (onRejection != null) {
            rejectionListeners.push(function(reason) {
              //onReject(reason).toPromise().then(resolve, reject);
            });
          }
        });
      case Fulfilled(value):
        if (onFulfillment != null) {
          fulfillmentListeners.push(onFulfillment);
          notify();
        }
      case Rejected(reason):
        if (onRejection != null) {
          rejectionListeners.push(onRejection);
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

  public static function resolve<TValue>(value : TValue) : Promise<TValue> {
    return new Promise(function(resolve, reject) {
      resolve(value);
    });
  }

  public static function reject(reason : Reason) : Promise<Nil> {
    return new Promise(function(resolve, reject) {
      reject(reason);
    });
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
}
