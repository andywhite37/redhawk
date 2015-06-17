package redhawk;

class Promise {
  public function new<TResult, TError>(resolver : ((Void -> TResult) -> (Void -> TError) -> Void)) {
  }

  public static function resolve<TResult, TError>(value : TResult) : Promise<TResult, TError> {
    return new Promise(function(resolve, reject) {
      resolve(value);
    });
  }

  public static function reject<TError>(error : TError) : Promise<Void, TError> {
    return new Promise(function(resolve, reject) {
      reject(error);
    });
  }

  public static function tries<TResult, TError>(callback : Void -> Promise<TResult, TError>) {
    try {
      //return callback()
    } catch (e : Dynamic) {
    }
  }
}
