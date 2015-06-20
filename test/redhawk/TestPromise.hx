package redhawk;

import haxe.Timer;
import redhawk.Promise;
import redhawk.State;
import utest.Assert;

class TestPromise {
  public function new() {}

  public function testStatePendingSync() {
    var promise = new Promise(function(resolve, reject) {
    });
    switch promise.state {
      case Pending: Assert.isTrue(true);
      case _: Assert.fail();
    };
  }

  public function testStatePendingAsync() {
    var done = Assert.createAsync();
    var promise = new Promise(function(resolve, reject) {
      Timer.delay(function() {
        resolve("test");
        done();
      }, 0);
    });
    switch promise.state {
      case Pending: Assert.isTrue(true);
      case _: Assert.fail();
    };
  }

  public function testStateFulfilledSync() {
    var promise = new Promise(function(resolve, reject) {
      resolve("test");
    });
    switch promise.state {
      case Fulfilled(value): Assert.same("test", value);
      case _: Assert.fail();
    };
  }

  public function testStateFulfilledAsync() {
    var done = Assert.createAsync();
    var promise = new Promise(function(resolve, reject) {
      Timer.delay(function() {
        resolve("test");
      }, 0);
    });
    switch promise.state {
      case Pending: Assert.isTrue(true);
      case _: Assert.fail();
    };

    promise.end(function(value) {
      switch promise.state {
        case Fulfilled(value): Assert.same("test", value);
        case _: Assert.fail();
      };
      done();
    });
  }

  public function testFulfilled() {
    var done = Assert.createAsync();
    var i = 0;

    Promise.fulfilled("test")
      .end(function(value) {
        Assert.same(2, ++i);
        Assert.same("test", value);
        done();
      });

    Assert.same(1, ++i);
  }

  public function testRejected() {
    var done = Assert.createAsync();

    Promise.rejected(new Reason("test"))
      .end(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.same("test", reason.value);
        done();
      });
  }

  public function testAsyncThen() {
    var done = Assert.createAsync();
    var i = 0;

    Promise.fulfilled("test")
      .end(function(value) {
        i++;
        Assert.same(2, i);
        done();
      });

    i++;
    Assert.same(1, i);
  }

  public function testEnd() {
    var done = Assert.createAsync();

    new Promise(function(resolve, reject) {
      resolve("test");
    })
    .end(function(value) {
      Assert.same("test", value);
      done();
    });
  }

  public function testChainOfValues() {
    var done = Assert.createAsync;
    var i = 0;

    Promise.fulfilled("test1")
      .then(function(value) {
        Assert.same(2, ++i);
        Assert.same("test1", value);
        return "test2";
      })
      .then(function(value) {
        Assert.same(3, ++i);
        Assert.same("test2", value);
        return "test3";
      })
      .end(function(value) {
        Assert.same(4, ++i);
        Assert.same("test3", value);
        done();
      });

    Assert.same(1, ++i);
  }

  public function testChainOfPromises() {
    var done = Assert.createAsync();
    var i = 0;

    Promise.fulfilled("test1")
      .then(function(value : String) {
        Assert.same(2, ++i);
        Assert.same("test1", value);
        return new Promise(function(resolve, reject) {
          resolve("test2");
        });
      })
      .then(function(value) {
        Assert.same(3, ++i);
        Assert.same("test2", value);
        return Promise.fulfilled("test3");
      })
      .end(function(value : String) {
        Assert.same(4, ++i);
        Assert.same("test3", value);
        done();
      });

    Assert.same(++i, 1);
  }

}
