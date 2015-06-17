package redhawk;

import redhawk.Promise;
import utest.Assert;

class TestPromise {
  public function new() {}

  public function testConstructor() {
    var promise = new Promise();
    Assert.isTrue(true);
  }
}
