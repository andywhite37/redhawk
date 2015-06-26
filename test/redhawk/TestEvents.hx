package redhawk;

import utest.Assert;

class TestEvents {
  public function new() {
  }

  public function testOn() {
    var events = new Events();
    var count = 0;

    events.on("test", function(_) {
      count++;
    });

    events.emit("test");
    events.emit("test");
    events.emit("test");

    Assert.same(3, count);
  }

  public function testOnce() {
    var events = new Events();
    var count = 0;

    events.once("test", function(_) {
      count++;
    });

    events.emit("test");
    events.emit("test");
    events.emit("test");

    Assert.same(1, count);
  }

  public function testOff() {
    var events = new Events();
    var count = 0;

    var callback = function(_) {
      count++;
    };

    events.on("test", callback);
    events.emit("test");
    events.emit("test");
    Assert.same(2, count);

    events.off("test", callback);
    events.emit("test");
    Assert.same(2, count);
  }

  public function testOffAll() {
    var events = new Events();
    var count1 = 0;
    var count2 = 0;

    var callback1 = function(_) {
      count1++;
    };

    var callback2 = function(_) {
      count2++;
    };

    events.on("test", callback1);
    events.on("test", callback1);
    events.on("test", callback2);

    events.emit("test");
    events.emit("test");
    Assert.same(4, count1);
    Assert.same(2, count2);

    events.off("test");

    events.emit("test");
    events.emit("test");
    Assert.same(4, count1);
    Assert.same(2, count2);
  }
}
