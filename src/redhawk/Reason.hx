package redhawk;

class Reason {
  public var message(default, null) : Null<String>;
  public var value(default, null) : Null<Dynamic>;

  public function new(?message : String, ?value: Dynamic) {
    this.message = message;
    this.value = value;
  }
}