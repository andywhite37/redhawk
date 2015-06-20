package redhawk;

import utest.Assert;

class TestReason {
  public function new() {}

  public function testReason() {
    var reason  = new Reason("test");
    Assert.same("test", reason.value);
  }
}
