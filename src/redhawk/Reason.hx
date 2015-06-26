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
  public var stack(default, null) : Array<StackItem>;

  public function new(value : Dynamic, ?stack : Array<StackItem>, ?pos : PosInfos) {
    this.value = value;
    this.pos = pos;
    if (stack != null) {
      this.stack = stack;
    } else {
      this.stack = try { CallStack.exceptionStack(); } catch (e : Dynamic) { []; };
      if (this.stack.length == 0) {
        this.stack = try { CallStack.callStack(); } catch (e: Dynamic) { []; };
      }
    }
  }

  public function is(type : Dynamic) : Bool {
    return Std.is(this, type);
  }

  public function as<T>(type : Dynamic) : T {
    return cast Std.instance(this, type);
  }

  @:to
  public function toString() : String {
    var stackString = CallStack.toString(stack);
    return 'Rejection reason from: ${pos.className}.${pos.methodName}() at ${pos.lineNumber}${stackString}\n';
  }
}

/**
 * Single type to use for any Promise rejection reason.
 * Abstract wrapper of CReason that has an implicit conversion from any value, so
 * you don't have to explicitly construct a Reason or CReason when rejecting a Promise.
 */
@:forward(value, pos, stackItems, toString)
abstract Reason(CReason) {
  public inline function new(?value : Dynamic) {
    this = new CReason(value);
  }

  @:from
  public static inline function fromDynamic(value : Dynamic) {
    return new Reason(value);
  }
}
