package redhawk;

import redhawk.Promise;
import redhawk.Nil;

enum EPromiseOrValue<TValue> {
  EPromise(promise : Promise<TValue>);
  EValue(value : Null<TValue>);
}

abstract PromiseOrValue<TValue>(EPromiseOrValue<TValue>) {
  public function new(promiseOrValue : EPromiseOrValue<TValue>) {
    this = promiseOrValue;
  }

  @:from
  public static function fromValue<TValue>(value : Null<TValue>) : PromiseOrValue<TValue> {
    return new PromiseOrValue(EValue(value));
  }

  @:from
  public static function fromPromise<TValue>(promise : Promise<TValue>) {
    return new PromiseOrValue(EPromise(promise));
  }

  @:to
  public function toPromise() : Promise<TValue> {
    return switch this {
      case EPromise(promise): promise;
      case EValue(value) : Promise.resolve(value);
    };
  }
}
