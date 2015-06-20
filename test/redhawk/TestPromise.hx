package redhawk;

import redhawk.Promise;
import utest.Assert;

class TestPromise {
  public function new() {}

  public function testDone() {
    var done = Assert.createAsync();

    new Promise(function(resolve, reject) {
      resolve("test");
    })
    .end(function(value) {
      Assert.same("test", value);
      done();
    });
  }

  public function testThenEnd() {
    var done = Assert.createAsync();

    new Promise(function(resolve1, reject1) {
      resolve1("test1");
    })
    .then(function(value1 : String) {
      trace("value1", value1);
      Assert.same("test1", value1);
      return new Promise(function(resolve2, reject2) {
        resolve2("test2");
      });
    })
    .end(function(value2 : String) {
      trace("value2", value2);
      Assert.same("test2", value2);
      done();
    });
  }
}
