package redhawk;

import StringTools;
import haxe.Timer;
import redhawk.Promise;
import redhawk.State;
import utest.Assert;

class TestPromise {
  public function new() {}

  public inline function debug() {
    untyped __js__("debugger;");
  }

  public function setup() {
    //Promise.off(Promise.UNHANDLED_REJECTION_EVENT);
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Constructor
  ////////////////////////////////////////////////////////////////////////////////

  public function testConstructor() {
    var promise = new Promise(function(resolve, reject) {
      // no-op
    });
    Assert.isTrue(promise.id >= 0);
    Assert.same("Promise: Test", promise.toString());
    Assert.same(Pending, promise.state);
  }

  public function testConstructorWithResolverException() {
    var done = Assert.createAsync();

    var reason = new Reason("This is a test");
    var promise : Promise<String> = null;

    try {
      promise = new Promise(function(resolve, reject) {
        throw reason;
      });
    } catch (e : Dynamic) {
      Assert.fail("Should not throw");
    }

    switch promise.state {
      case Rejected(stateReason): Assert.equals(reason, stateReason);
      case _: Assert.fail();
    };

    promise.thenv(function(value) {
      Assert.fail();
      done();
    }, function(rejectionReason) {
      Assert.equals(reason, rejectionReason);
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
    promise.thenv(function(value) {
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
    var done = Assert.createAsync();

    Promise.once(Promise.UNHANDLED_REJECTION_EVENT, function(reason : Reason) {
      Assert.pass();
      done();
    });

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

    promise.thenv(function(value) {
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
      .thenv(function(value) {
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
      .thenv(function(value) {
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
      .thenv(function(value) {
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
      .thenv(function(value : String) {
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

      .thenv(function(value) {
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
      .catchesv(function(reason) {
        Assert.same("error", reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .thenv member function
  ////////////////////////////////////////////////////////////////////////////////

  public function testEnd() {
    var done = Assert.createAsync();

    new Promise(function(resolve, reject) {
      resolve("test");
    })
    .thenv(function(value) {
      Assert.same("test", value);
      done();
    });
  }

  public function testEndAsync() {
    var done = Assert.createAsync();
    var i = 0;

    Promise.fulfilled("test")
      .thenv(function(value) {
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
  // .catches/.catchesv member functions
  ////////////////////////////////////////////////////////////////////////////////

  public function testCatches() {
    var done = Assert.createAsync();

    Promise.rejected("test")
      .catches(function(reason) {
        Assert.same("test", reason.value);
        return "test2";
      })
      .thenv(function(_) {
        Assert.pass();
        done();
      });
  }

  public function testCatchesEnd() {
    var done = Assert.createAsync();

    Promise.rejected("test")
      .catchesv(function(reason) {
        Assert.same("test", reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .finally member function
  ////////////////////////////////////////////////////////////////////////////////

  public function testFinallyEndFulfilled() {
    var done = Assert.createAsync();
    var i = 0;
    Promise.fulfilled("test")
      .finally(function() {
        i++;
        Assert.same(1, i);
      })
      .thenv(function(value) {
        i++;
        Assert.same(2, i);
        Assert.same("test", value);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testFinallyRejected() {
    var done = Assert.createAsync();
    var i = 0;
    Promise.rejected("test")
      .finally(function() {
        i++;
        Assert.same(1, i);
      })
      .thenv(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        i++;
        Assert.same(2, i);
        Assert.same("test", reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .thenFulfilled member function
  ////////////////////////////////////////////////////////////////////////////////

  public function testThenFulfilled() {
    var done = Assert.createAsync();
    Promise.delayed(0)
      .thenFulfilled("test")
      .thenv(function(value) {
        Assert.same("test", value);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // .thenRejected member function
  ////////////////////////////////////////////////////////////////////////////////

  public function testThenRejected() {
    var done = Assert.createAsync();
    Promise.delayed(0)
      .thenRejected("test")
      .thenv(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.same("test", reason.value);
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
        throw new Reason("Failed test");
      })
      .then(function(value) {
        throw new Reason("test error 1");
      }, function(reason) {
        Assert.fail();
        throw new Reason("Failed test");
      })
      .thenv(function(value) {
        Assert.fail();
        throw new Reason("Failed test");
      }, function(reason) {
        Assert.same("test error 1", reason.value);
        done();
      });
  }

  public function testTriesWithRejection() {
    var done = Assert.createAsync();

    Promise
      .tries(function() {
        return Promise.rejected("my rejection");
      })
      .catchesv(function(reason) {
        Assert.same("my rejection", reason.value);
        done();
      });
  }

  public function testTriesWithException() {
    debug();
    trace('testTriesWithException');
    var done = Assert.createAsync();

    Promise
      .tries(function() {
        throw new Reason("problem");
      })
      .thenv(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.same("problem", reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.all static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testAllInputsFulfilled() {
    var done = Assert.createAsync();

    Promise.all(["test1", Promise.fulfilled(1), Promise.fulfilled(true), "test2"])
      .thenv(function(results) {
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

  public function testAllInputsRejected() {
    var done = Assert.createAsync();

    Promise.all([Promise.rejected("test1"), Promise.rejected("test2")])
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same(1, reasons.length);
        Assert.same("test1", reasons[0].value);
        done();
      });
  }

  public function testAllInputsMixed() {
    var done = Assert.createAsync();

    Promise.all(["test1", Promise.rejected("test2"), Promise.fulfilled("test3")])
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.equals(null, reasons[0]);
        Assert.equals("test2", reasons[1].value);
        Assert.equals(null, reasons[2]);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.any static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testAnyInputsFulfilled() {
    var done = Assert.createAsync();

    Promise.any(["test1", Promise.fulfilled("test2")])
      .thenv(function(result) {
        Assert.isTrue(result == "test1" || result == "test2");
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testAnyInputsRejected() {
    var done = Assert.createAsync();

    Promise.any([Promise.rejected("test1"), Promise.rejected("test2")])
      .thenv(function(result) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same("test1", reasons[0].value);
        Assert.same("test2", reasons[1].value);
        done();
      });
  }

  public function testAnyInputsMixed() {
    var done = Assert.createAsync();

    Promise.any([Promise.rejected("test1"), "test2", Promise.rejected("test3")])
      .thenv(function(result) {
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

  public function testManyInputsFulfilled() {
    var done = Assert.createAsync();

    Promise.many(["test1", "test2", "test3"], 2)
      .thenv(function(results) {
        Assert.same(2, results.length);
        Assert.isTrue("test1" == results[0]);
        Assert.isTrue("test2" == results[1]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testManyEnoughInputsFulfilled() {
    var done = Assert.createAsync();

    Promise.many(["test1", Promise.rejected("test2"), "test3"], 2)
      .thenv(function(results) {
        Assert.same(3, results.length);
        Assert.isTrue("test1" == results[0]);
        Assert.equals(null, results[1]);
        Assert.isTrue("test3" == results[2]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testManyInputsNotEnoughFulfilled() {
    var done = Assert.createAsync();

    Promise.many([Promise.rejected("test1"), "test2", Promise.rejected("test3")], 2)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same("test1", reasons[0].value);
        Assert.same(null, reasons[1]);
        Assert.same("test3", reasons[2].value);
        done();
      });
  }

  function testManyInputsRejected() {
    var done = Assert.createAsync();

    Promise.many([Promise.rejected("test1"), Promise.rejected("test2"), Promise.rejected("test3")], 2)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same("test1", reasons[0].value);
        Assert.same("test2", reasons[1].value);
        Assert.same("test3", reasons[2].value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.settled static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testSettledAllFulfilled() {
    var done = Assert.createAsync();
    Promise.settled(["test1", Promise.fulfilled("test2"), Promise.fulfilled("test3")])
      .thenv(function(promises) {
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
      .thenv(function(promises) {
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
      .thenv(function(promises) {
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

  function mapper(inputValue : String) : PromiseOrValue<Int> {
    return new Promise(function(resolve, reject) {
      Timer.delay(function() {
        var num = Std.parseInt(~/test/.replace(inputValue, ""));
        if (num >= 0) {
          resolve(num);
        } else {
          reject('Number cannot be negative');
        }
      }, 0);
    });
  }

  public function testMapInputsFulfilledMapperFulfilled() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = [
      "test1",
      Promise.fulfilled("test2"),
      Promise.fulfilled("test3")
    ];
    Promise.map(inputs, mapper)
      .thenv(function(results) {
        Assert.same(3, results.length);
        Assert.same(1, results[0]);
        Assert.same(2, results[1]);
        Assert.same(3, results[2]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testMapInputsFulfilledMapperRejected() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = ["test-1", "test-2", "test-3", "test-4"];
    Promise.map(inputs, mapper)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  public function testMapInputsRejected() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = [
      Promise.rejected("test1"),
      Promise.rejected("test2"),
      Promise.rejected("test3")
    ];
    Promise.map(inputs, mapper)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  public function testMapInputsMixedMapperMixed() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = [
      Promise.fulfilled("test1"),
      Promise.rejected("test2"),
      Promise.fulfilled("test-1"),
      Promise.rejected("test-2")
    ];
    Promise.map(inputs, mapper)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.each static function
  ////////////////////////////////////////////////////////////////////////////////

  function eachCallback(inputValue : String) : PromiseOrValue<Nil> {
    return new Promise(function(resolve, reject) {
      Timer.delay(function() {
        if (inputValue.indexOf("-") > 0) {
          reject('Cannot contain -');
        } else {
          resolve(Nil.nil);
        }
      }, 0);
    });
  }

  public function testEachInputsFulfilledCallbackFulfilled() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = ["test1", "test2", "test3"];
    Promise.each(inputs, eachCallback)
      .thenv(function(results) {
        Assert.same(3, results.length);
        Assert.same("test1", results[0]);
        Assert.same("test2", results[1]);
        Assert.same("test3", results[2]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testEachInputsFulfilledCallbackRejected() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = ["test1", "test-2", "test3", "test-4"];
    Promise.each(inputs, eachCallback)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  public function testEachInputsRejected() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = [Promise.rejected("test1"), Promise.rejected("test2")];
    Promise.each(inputs, eachCallback)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  public function testEachInputsMixedCallbackMixed() {
    var done = Assert.createAsync();
    var inputs : Array<PromiseOrValue<String>> = [
      Promise.fulfilled("test1"),
      Promise.rejected("test2"),
      Promise.fulfilled("test-3"),
      Promise.rejected("test-4")
    ];
    Promise.each(inputs, eachCallback)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.pass();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.reduce static function
  ////////////////////////////////////////////////////////////////////////////////

  public function reducer(acc : Int, value : Int) : PromiseOrValue<Int> {
    return Promise.delayed(0)
      .thenFulfilled(acc + value);
  }

  public function testReduceInputsFulfilledReducerFulfilled() {
    var inputs : Array<PromiseOrValue<Int>> = [1, 2, 3, 4, 5];
    var done = Assert.createAsync(1000);
    Promise.reduce(inputs, reducer, 0)
      .thenv(function(value) {
        Assert.same(15, value);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testReduceInputsRejected() {
    var inputs : Array<PromiseOrValue<Int>> = [1, 2, Promise.rejected(3), 4, 5];
    var done = Assert.createAsync(1000);
    Promise.reduce(inputs, reducer, 0)
      .thenv(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same(3, reasons[2].value);
        done();
      });
  }

  public function testReduceInputsFulfilledReducerRejected() {
    var inputs : Array<PromiseOrValue<Int>> = [1, 2, 3, 4, 5];
    var done = Assert.createAsync(1000);
    var reducerRejection = function(acc : Int, input : Int) : PromiseOrValue<Int> {
      if (input == 3) {
        return Promise.rejected('sorry');
      } else {
        return Promise.fulfilled(acc + input);
      }
    };
    Promise.reduce(inputs, reducerRejection, 0)
      .thenv(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same('sorry', reasons[2].value);
        done();
      });
  }

  public function testReduceMixedTypes() {
    var inputs : Array<PromiseOrValue<String>> = ["1", "2", "3", "4", "5"];
    var done = Assert.createAsync(1000);
    var reducer = function(acc : { sum: Int, product : Int }, input : String) : PromiseOrValue<{ sum: Int, product: Int }> {
      return Promise.tries(function() {
        var num = Std.parseInt(input);
        acc.sum += num;
        acc.product *= num;
        return acc;
      });
    }

    Promise.reduce(inputs, reducer, { sum: 0, product: 1 })
      .thenv(function(value) {
        Assert.same(1 + 2 + 3 + 4 + 5, value.sum);
        Assert.same(1 * 2 * 3 * 4 * 5, value.product);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.filter static function
  ////////////////////////////////////////////////////////////////////////////////

  public function testFilterInputsFulfilledFiltererFulfilled() {
    var done = Assert.createAsync(1000);
    var inputs : Array<PromiseOrValue<Int>> = [1, 2, 3, 4, 5];
    var filterer = function(input : Int) : PromiseOrValue<Bool> {
      return input < 4;
    };

    Promise.filter(inputs, filterer)
      .thenv(function(results) {
        Assert.same(3, results.length);
        Assert.same(1, results[0]);
        Assert.same(2, results[1]);
        Assert.same(3, results[2]);
        done();
      }, function(reason) {
        Assert.fail();
        done();
      });
  }

  public function testFilterInputsRejected() {
    var done = Assert.createAsync(1000);
    var inputs : Array<PromiseOrValue<Int>> = [Promise.rejected(1), Promise.rejected(2)];
    var filterer = function(input : Int) : PromiseOrValue<Bool> {
      return input < 4;
    };
    Promise.filter(inputs, filterer)
      .thenv(function(results) {
        Assert.fail();
        done();
      }, function(reason) {
        var reasons : Array<Reason> = reason.value;
        Assert.same(reasons.length, 1);
        Assert.same(1, reasons[0].value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Promise.delayed static
  ////////////////////////////////////////////////////////////////////////////////

  public function testDelayed() {
    var ms = 50;
    var done = Assert.createAsync(1000);
    var startTime = Date.now().getTime();
    Promise.delayed(ms)
      .thenv(function(_) {
        var endTime = Date.now().getTime();
        var duration = endTime - startTime;
        Assert.isTrue(duration >= ms);
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
    var done = Assert.createAsync(1000);
    var startTime = Date.now().getTime();

    Promise.fulfilled("test")
      .delay(ms)
      .thenv(function(_) {
        var endTime = Date.now().getTime();
        var duration = endTime - startTime;
        Assert.isTrue(duration >= ms);
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
      .thenv(function(value) {
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
      .thenv(function(value) {
        Assert.fail();
        done();
      }, function(reason) {
        Assert.same('error', reason.value);
        done();
      });
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Other tests
  ////////////////////////////////////////////////////////////////////////////////

  public function testMultipleHandlers() {
    var done = Assert.createAsync(1000);

    var count = 0;
    function check(value : String) {
      count++;
      Assert.same("test", value);
      if (count == 3) {
        done();
      }
    }

    var promise = Promise.fulfilled("test");

    promise.thenv(check);
    promise.thenv(check);
    promise.thenv(check);
  }

  public function testNoErrorHandler() {
    var done = Assert.createAsync(1000);

    Promise.once(Promise.UNHANDLED_REJECTION_EVENT, function(reason) {
      //Assert.pass();
      done();
    });

    Promise.rejected("my error");
  }
}
