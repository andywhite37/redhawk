package redhawk;

import redhawk.Promise;

enum EPromiseOrValue<TValue> {
  EPromise(promise : Promise<TValue>);
  EValue(value : TValue);
}

abstract PromiseOrValue<TValue>(EPromiseOrValue<TValue>) {
  public function new(promiseOrValue : EPromiseOrValue<TValue>) {
    this = promiseOrValue;
  }

  @:from
  public static function fromPromise<TValue>(promise : Promise<TValue>) {
    return new PromiseOrValue(EPromise(promise));
  }

  @:from
  public static function fromValue<TValue>(value : Null<TValue>) : PromiseOrValue<TValue> {
    return new PromiseOrValue(EValue(value));
  }

  @:to
  public function toPromise() : Promise<TValue> {
    return switch this {
      case EPromise(promise): promise;
      case EValue(value) : Promise.fulfilled(value);
    };
  }

  public function isValue() {
    return switch this {
      case EPromise(promise): false;
      case EValue(value): true;
    };
  }

  public function isPromise() {
    return switch this {
      case EPromise(promise): true;
      case EValue(value): false;
    };
  }
}
