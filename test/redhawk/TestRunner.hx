package redhawk;
import utest.Runner;

class TestRunner {
  public static function main() {
    var runner = new Runner();
    runner.addCase(new TestPromise());
    runner.run();
  }
}
