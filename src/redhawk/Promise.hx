package redhawk;

class Promise<TResult, TError> {
  public function new() {
  }

  public static function tries<TResult, TError>(callback : Void -> Promise<TResult, TError>) {
    try {
      //return callback()
    } catch (e : Dynamic) {
    }
  }
}
