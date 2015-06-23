package redhawk;

import js.Error;
import haxe.Timer;
import redhawk.Promise;
import redhawk.State;
import utest.Assert;

class TestPromise {
  public function new() {}

  ////////////////////////////////////////////////////////////////////////////////
  // Constructor
  ////////////////////////////////////////////////////////////////////////////////

  public function testConstructor() {
    var promise = new Promise("Test", function(resolve, reject) {
      // no-op
    });
    Assert.same("Promise: Test", promise.name);
    Assert.isTrue(promise.id > 0);
    Assert.same("Promise: Test", promise.toString());
    Assert.same(Pending, promise.state);
  }

  public function testConstructorWithResolverException() {
    var done = Assert.createAsync();

    var error = new Error("This is a test");
    var promise : Promise<String> = null;

    try {
      promise = new Promise(function(resolve, reject) {
        throw error;
      });
    } catch (e : Dynamic) {
      Assert.fail("Should not throw");
    }

    switch promise.state {
      case Rejected(reason): Assert.equals(error, reason.value);
      case _: Assert.fail();
    };

    promise.end(function(value) {
      Assert.fail();
      done();
    }, function(reason) {
      Assert.equals(error, reason.value);
      done();
    });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .state member variable
  ////////////////////////////////////////////////////////////////////////////////

  public function testStatePendingSync() {
    var promise = new Promise(function(resolve, reject) {
      // no-op
    });
    switch promise.state {
      case Pending: Assert.pass();
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
      case Pending: Assert.pass();
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
      case Pending: Assert.pass();
      case _: Assert.fail();
    };
    promise.end(function(value) {
      switch promise.state {
        case Fulfilled(value): Assert.same("test", value);
        case _: Assert.fail();
      };
      done();
    }, function(reason) {
      Assert.fail();
      done();
    });
  }

  public function testStateRejectedSync() {
    var promise = new Promise(function(resolve, reject) {
      reject("test");
    });

    switch promise.state {
      case Rejected(reason): Assert.same("test", reason.value);
      case _: Assert.fail();
    };
  }

  public function testStateRejectedAsync() {
    var done = Assert.createAsync();

    var promise = new Promise(function(resolve, reject) {
      Timer.delay(function() {
        reject("test");
      }, 0);
    });

    switch promise.state {
      case Pending: Assert.pass();
      case _: Assert.fail();
    };

    promise.end(function(value) {
      Assert.fail();
      done();
    }, function(reason) {
      switch promise.state {
        case Rejected(reason): Assert.same("test", reason.value);
        case _: Assert.fail();
      };
      done();
    });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.fulfilled/Promise.rejected static functions
  ////////////////////////////////////////////////////////////////////////////////

  public function testFulfilled() {
    var done = Assert.createAsync();
    var i = 0;

    Promise.fulfilled("test")
      .end(function(value) {
        Assert.same(2, ++i);
        Assert.same("test", value);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });

    Assert.same(1, ++i);
  }

  public function testRejected() {
    var done = Assert.createAsync();

    var error = { message: "test" };
    Promise.rejected(error)
      .end(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.equals(error, reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .then member function
  ////////////////////////////////////////////////////////////////////////////////

  public function testThenWithChainOfValues() {
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

  public function testThenWithChainOfPromises() {
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

  public function testThenWithMix() {
    var done = Assert.createAsync();

    Promise.fulfilled("test1")
      .then(function(value) {
        Assert.same("test1", value);
        return Promise.rejected("error1");
      }, function(reason) {
        Assert.fail();
        return Promise.rejected("Test failed");
      })

      .then(function(value) {
        Assert.fail();
        return Promise.rejected("Test failed");
      }, function(reason) {
        Assert.same("error1", reason.value);
        return Promise.fulfilled("test2");
      })

      .end(function(value) {
        Assert.same("test2", value);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testThenRejectionCascading() {
    var done = Assert.createAsync();

    Promise.rejected("error")
      .then(function(value) {
        Assert.fail();
        return "test1";
      })
      .then(function(value) {
        Assert.fail();
        return "test2";
      })
      .catchesEnd(function(reason) {
        Assert.same("error", reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .end member function
  ////////////////////////////////////////////////////////////////////////////////

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

  public function testEndAsync() {
    var done = Assert.createAsync();
    var i = 0;

    Promise.fulfilled("test")
      .end(function(value) {
        i++;
        Assert.same(2, i);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });

    i++;
    Assert.same(1, i);
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .catches/.catchesEnd member functions
  ////////////////////////////////////////////////////////////////////////////////

  public function testCatches() {
    var done = Assert.createAsync();

    Promise.rejected("test")
      .catches(function(reason) {
        Assert.same("test", reason.value);
        return "test2";
      })
      .end(function(_) {
        Assert.pass();
        done();
      });
  }

  public function testCatchesEnd() {
    var done = Assert.createAsync();

    Promise.rejected("test")
      .catchesEnd(function(reason) {
        Assert.same("test", reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .always member function
  ////////////////////////////////////////////////////////////////////////////////

  public function testAlwaysWithFulfillment() {
    var done = Assert.createAsync();
    Promise.fulfilled("test")
      .finally(function() {
        Assert.pass();
        done();
      });
  }

  public function testAlwaysWithRejection() {
    var done = Assert.createAsync();
    Promise.rejected("test")
      .finally(function() {
        Assert.pass();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.tries static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testTries() {
    var done = Assert.createAsync();

    Promise
      .tries(function() {
        return "test1";
      })
      .then(function(value) {
        return Promise.fulfilled("test2");
      }, function(reason) {
        Assert.fail();
        throw new Error("Failed test");
      })
      .then(function(value) {
        throw new Error("test error 1");
      }, function(reason) {
        Assert.fail();
        throw new Error("Failed test");
      })
      .end(function(value) {
        Assert.fail();
        throw new Error("Failed test");
      }, function(reason) {
        var error : Error = reason.value;
        Assert.same("test error 1", error.message);
        done();
      });
  }

  public function testTriesWithException() {
    var done = Assert.createAsync();

    Promise
      .tries(function() {
        throw new Error("problem");
      })
      .end(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        var error : Error = reason.value;
        Assert.same("problem", error.message);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.all static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testAllFulfilled() {
    var done = Assert.createAsync();

    Promise.all(["test1", Promise.fulfilled(1), Promise.fulfilled(true), "test2"])
      .end(function(results) {
        Assert.same("test1", results[0]);
        Assert.same(1, results[1]);
        Assert.same(true, results[2]);
        Assert.same("test2", results[3]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testAllRejected() {
    var done = Assert.createAsync();

    Promise.all([Promise.rejected("test1"), Promise.rejected("test2")])
      .end(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  public function testAllMixed() {
    var done = Assert.createAsync();

    Promise.all(["test1", Promise.rejected("test2"), Promise.fulfilled("test3")])
      .end(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.any static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testAnyFulfilled() {
    var done = Assert.createAsync();

    Promise.any(["test1", Promise.fulfilled("test2")])
      .end(function(result) {
        Assert.isTrue(result == "test1" || result == "test2");
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testAnyRejected() {
    var done = Assert.createAsync();

    Promise.any([Promise.rejected("test1"), Promise.rejected("test2")])
      .end(function(result) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.isTrue(reason.value == "test1" || reason.value == "test2");
        done();
      });
  }

  public function testAnyMix() {
    var done = Assert.createAsync();

    Promise.any([Promise.rejected("test1"), "test2", Promise.rejected("test3")])
      .end(function(result) {
        Assert.same("test2", result);
        done();
      }, function(reason) {
        Assert.isTrue(reason.value == "test1" || reason.value == "test2");
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.many static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testManyAllFulfilled() {
    var done = Assert.createAsync();

    Promise.many(["test1", Promise.fulfilled("test2"), "test3"], 2)
      .end(function(results) {
        Assert.same(2, results.length);
        Assert.isTrue("test1" == results[0] || "test2" == results[0] || "test3" == results[0]);
        Assert.isTrue("test1" == results[1] || "test2" == results[1] || "test3" == results[1]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testManyNotEnoughFulfilled() {
    var done = Assert.createAsync();

    Promise.many([Promise.rejected("test1"), "test2", Promise.rejected("test3")], 2)
      .end(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.settled static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testSettledAllFulfilled() {
    var done = Assert.createAsync();

    Promise.settled(["test1", Promise.fulfilled("test2"), Promise.fulfilled("test3")])
      .end(function(promises) {
        Assert.isTrue(promises[0].isFulfilled());
        Assert.same("test1", promises[0].getValue());

        Assert.isTrue(promises[1].isFulfilled());
        Assert.same("test2", promises[1].getValue());

        Assert.isTrue(promises[2].isFulfilled());
        Assert.same("test3", promises[2].getValue());

        done();
      });
  }

  public function testSettledAllRejected() {
    var done = Assert.createAsync();

    Promise.settled([Promise.rejected("test1"), Promise.rejected("test2"), Promise.rejected("test3")])
      .end(function(promises) {
        Assert.isTrue(promises[0].isRejected());
        Assert.same("test1", promises[0].getReason().value);

        Assert.isTrue(promises[1].isRejected());
        Assert.same("test2", promises[1].getReason().value);

        Assert.isTrue(promises[2].isRejected());
        Assert.same("test3", promises[2].getReason().value);

        done();
      });
  }

  public function testSettledMixed() {
    var done = Assert.createAsync();

    Promise.settled([Promise.rejected("test1"), "test2", Promise.fulfilled("test3"), Promise.rejected("test4")])
      .end(function(promises) {
        Assert.isTrue(promises[0].isRejected());
        Assert.same("test1", promises[0].getReason().value);

        Assert.isTrue(promises[1].isFulfilled());
        Assert.same("test2", promises[1].getValue());

        Assert.isTrue(promises[2].isFulfilled());
        Assert.same("test3", promises[2].getValue());

        Assert.isTrue(promises[3].isRejected());
        Assert.same("test4", promises[3].getReason().value);

        done();

      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.map static function
  ////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////////
  // .map member function
  ////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.delayed static
  ////////////////////////////////////////////////////////////////////////////////

  public function testDelayed() {
    var ms = 50;
    var done = Assert.createAsync(ms * 2);
    var startTime = Date.now().getTime();

    Promise.delayed(ms)
      .end(function(_) {
        var endTime = Date.now().getTime();
        var duration = endTime - startTime;
        trace('duration: $duration');
        Assert.isTrue(duration > ms);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .delay (chainable)
  ////////////////////////////////////////////////////////////////////////////////

  public function testDelay() {
    var ms = 50;
    var done = Assert.createAsync(ms * 2);
    var startTime = Date.now().getTime();

    Promise.fulfilled("test")
      .delay(ms)
      .end(function(_) {
        var endTime = Date.now().getTime();
        var duration = endTime - startTime;
        Assert.isTrue(duration > ms);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .tap
  ////////////////////////////////////////////////////////////////////////////////

  public function testTap() {
    var done = Assert.createAsync();

    Promise.fulfilled("test")
      .tap(function(value) {
        Assert.same("test", value);
      })
      .end(function(value) {
        Assert.same("test", value);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testTapError() {
    var done = Assert.createAsync();
    Promise.fulfilled("test")
      .tap(function(value) {
        throw 'error';
      })
      .end(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.same('error', reason.value);
        done();
      });
  }
}
