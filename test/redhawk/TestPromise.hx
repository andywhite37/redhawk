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
  // State
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
  // Static constructors
  ////////////////////////////////////////////////////////////////////////////////

  public function testFulfilledHelper() {
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

  public function testRejectedHelper() {
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
  // .then
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
  // .end
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
  // .catches/.catchesEnd
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
  // .always
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
  // .tries
  ////////////////////////////////////////////////////////////////////////////////

  public function testTriesHelper() {
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
  // .join
  ////////////////////////////////////////////////////////////////////////////////

  public function testJoinAllFulfilled() {
    var done = Assert.createAsync();

    Promise.join("test1", Promise.fulfilled("test2"))
      .end(function(result) {
        Assert.same("test1", result.value1);
        Assert.same("test2", result.value2);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .all
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

  public function testAllMix() {
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
}
