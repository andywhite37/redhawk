package redhawk;

import utest.Assert;

class TestReason {
  public function new() {}

  public function testConstructor() {
    var reason  = new Reason("test");
    Assert.same("test", reason.value);
  }

  public function testFromDynamic() {
    var reason1 = Reason.fromDynamic("test1");
    Assert.same("test1", reason1.value);

    var reason2 = Reason.fromDynamic(reason1);
    Assert.equals(reason1, reason2);

    var reason3 : Reason = 'test2';
    Assert.equals('test2', reason3.value);
  }
}
