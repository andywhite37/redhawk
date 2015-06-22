package redhawk;

import utest.Assert;

class TestReason {
  public function new() {}

  public function testConstructor() {
    var reason  = new Reason("test");
    Assert.same("test", reason.value);
  }

  public function testFromDynamic() {
    var reason : Reason = "test";
    Assert.same("test", reason.value);
  }
}
