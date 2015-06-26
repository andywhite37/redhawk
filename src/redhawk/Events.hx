package redhawk;

import haxe.ds.StringMap;
using Lambda;

class Handler {
  public var callback : Dynamic -> Void;
  public var callsRemaining : Null<Int>;

  public function new(callback : Dynamic -> Void, ?callsRemaining : Int) {
    this.callback = callback;
    this.callsRemaining = callsRemaining;
  }
}

class Events {
  var handlerMap : StringMap<Array<Handler>>;

  public function new() {
    handlerMap = new StringMap();
  }

  public function on(name : String, callback: Dynamic -> Void) {
    subscribe(name, callback);
  }

  public function once(name : String, callback : Dynamic -> Void) {
    subscribe(name, callback, 1);
  }

  public function twice(name : String, callback : Dynamic -> Void) {
    subscribe(name, callback, 2);
  }

  public function times(name : String, callback : Dynamic -> Void, count : Int) {
    subscribe(name, callback, count);
  }

  public function off(name : String, ?callback : Dynamic -> Void) {
    ensure(name);
    if (callback != null) {
      handlerMap.set(name, handlerMap.get(name).filter(function(handler) {
        return handler.callback != callback;
      }));
    } else {
      handlerMap.set(name, []);
    }
  }

  public function emit(name : String, ?data : Dynamic) {
    ensure(name);
    for (handler in handlerMap.get(name)) {
      handler.callback(data);
      if (handler.callsRemaining != null) {
        handler.callsRemaining--;
      }
    }
    handlerMap.set(name, handlerMap.get(name).filter(function(handler) {
      return handler.callsRemaining == null || handler.callsRemaining > 0;
    }));
  }

  function subscribe(name : String, callback : Dynamic -> Void, ?callsRemaining : Int) {
    ensure(name);
    handlerMap.get(name).push(new Handler(callback, callsRemaining));
  }

  function ensure(name : String) {
    if (!handlerMap.exists(name)) {
      handlerMap.set(name, []);
    }
  }
}
