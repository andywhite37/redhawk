package redhawk;

import utest.Assert;

class TestPromiseOrValue {
  public function new() { }

  public function testConstructor() {
    var pov = new PromiseOrValue(EValue("test"));
    Assert.isTrue(pov.isValue());
    Assert.isFalse(pov.isPromise());
  }

  public function testFromValueExplicit() {
    var pov = PromiseOrValue.fromValue("test");
    Assert.isTrue(pov.isValue());
    Assert.isFalse(pov.isPromise());
  }

  public function testFromValueImplicit() {
    var pov : PromiseOrValue<String> = "test";
    Assert.isTrue(pov.isValue());
    Assert.isFalse(pov.isPromise());
  }

  public function testFromPromiseExplicit() {
    var pov = PromiseOrValue.fromPromise(Promise.fulfilled("test"));
    Assert.isFalse(pov.isValue());
    Assert.isTrue(pov.isPromise());
  }

  public function testFromPromiseImplicit() {
    var pov : PromiseOrValue<String> = Promise.fulfilled("test");
    Assert.isFalse(pov.isValue());
    Assert.isTrue(pov.isPromise());
  }

  public function testToPromiseFromValue() {
    var done = Assert.createAsync();
    var pov : PromiseOrValue<String> = "test";
    var promise = pov.toPromise();
    Assert.isTrue(Std.is(promise, Promise));
    promise.end(function(value) {
      Assert.same("test", value);
      done();
    });
  }

  public function testToPromiseFromPromise() {
    var done = Assert.createAsync();
    var promiseOrig = Promise.fulfilled("test");
    var pov : PromiseOrValue<String> = promiseOrig;
    var promise = pov.toPromise();
    Assert.equals(promiseOrig, promise);
    promise.end(function(value) {
      Assert.same("test", value);
      done();
    });
  }
}
