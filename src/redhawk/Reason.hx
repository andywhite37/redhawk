package redhawk;

class Reason {
  public var value(default, null) : Null<Dynamic>;

  public function new(?value : Dynamic) {
    this.value = value;
  }
}
