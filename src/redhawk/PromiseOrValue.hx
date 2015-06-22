package redhawk;

import redhawk.Promise;

enum EPromiseOrValue<TValue> {
  EPromise(promise : Promise<TValue>);
  EValue(value : TValue);
}

abstract PromiseOrValue<TValue>(EPromiseOrValue<TValue>) {
  /**
   * Constructs this instance from either a Promise<TValue> or a TValue
   */
  public function new(promiseOrValue : EPromiseOrValue<TValue>) {
    this = promiseOrValue;
  }

  /**
   * Implicit conversion from a Promise<TValue>
   */
  @:from
  public static function fromPromise<TValue>(promise : Promise<TValue>) {
    return new PromiseOrValue(EPromise(promise));
  }

  /**
   * Implicit conversion from a TValue
   */
  @:from
  public static function fromValue<TValue>(value : Null<TValue>) : PromiseOrValue<TValue> {
    return new PromiseOrValue(EValue(value));
  }

  /**
   * Implicit conversion to a Promise<TValue>.
   * If already a Promise<TValue>, it is returned unchanged.  If a TValue, it is converted
   * into a fulfilled Promise<TValue>.
   */
  @:to
  public function toPromise() : Promise<TValue> {
    return switch this {
      case EPromise(promise): promise;
      case EValue(value) : Promise.fulfilled(value);
    };
  }

  /**
   * Checks if this instance contains a plain TValue
   */
  public function isValue() {
    return switch this {
      case EPromise(promise): false;
      case EValue(value): true;
    };
  }

  /**
   * Checks if this instance contains a Promise<TValue>
   */
  public function isPromise() {
    return switch this {
      case EPromise(promise): true;
      case EValue(value): false;
    };
  }
}
