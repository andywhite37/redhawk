package redhawk;

import haxe.PosInfos;
import haxe.CallStack;

/**
 * Container for any value.  The purpose of this class is to have a single class to use
 * for a Promise rejection reason.
 */
class CReason {
  public var value(default, null) : Dynamic;
  public var pos(default, null) : PosInfos;
  public var stack(default, null) : String;

  public function new(value : Dynamic, ?stack : String, ?pos : PosInfos) {
    this.value = value;
    this.pos = pos;
    this.stack = stack != null ? stack : getStack();
  }

  public function is(type : Dynamic) : Bool {
    return Std.is(this, type);
  }

  public function as<T>(type : Dynamic) : T {
    return cast Std.instance(this, type);
  }

  @:to
  public function toString() : String {
    return 'Rejection reason from: ${pos.className}.${pos.methodName}() at ${pos.lineNumber}${stack}\n';
  }

  function getStack() {
    var stack = try {
      CallStack.exceptionStack();
    } catch (e : Dynamic) {
      try {
        CallStack.callStack();
      } catch (e : Dynamic) {
        [];
      }
    }
    return CallStack.toString(stack);
  }
}

/**
 * Single type to use for any Promise rejection reason.
 * Abstract wrapper of CReason that has an implicit conversion from any value, so
 * you don't have to explicitly construct a Reason or CReason when rejecting a Promise.
 */
@:forward(value, pos, stackItems, toString)
abstract Reason(CReason) {
  public function new(?value : Dynamic) {
    this = new CReason(value);
  }

  @:from
  public static function fromDynamic(value : Dynamic) {
    return new Reason(value);
  }
}
