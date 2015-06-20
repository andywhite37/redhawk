package redhawk;

import redhawk.Promise;
import utest.Assert;

class TestPromise {
  public function new() {}

  public function testConstructor() {
    var done = Assert.createAsync();

    var promise = new Promise(function(resolve, reject) {
      resolve("test");
    });

    promise.then(function(value) {
      Assert.same("test", value);
      done();
      return null;
    });
  }
}
