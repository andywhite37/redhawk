package redhawk;

/**
 * Container for any value.  The purpose of this class is to have a single class to use
 * for a Promise rejection reason.
 */
class CReason {
  public var value(default, null) : Dynamic;

  public function new(value : Dynamic) {
    this.value = value;
  }
}

/**
 * Single type to use for any Promise rejection reason.
 * Abstract wrapper of CReason that has an implicit conversion from any value, so
 * you don't have to explicitly construct a Reason or CReason when rejecting a Promise.
 */
@:forward(value)
abstract Reason(CReason) {
  public function new(?value : Dynamic) {
    this = new CReason(value);
  }

  @:from
  public static function fromDynamic(value : Dynamic) {
    return new Reason(value);
  }
}
