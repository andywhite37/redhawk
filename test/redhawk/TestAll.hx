package redhawk;

import utest.Runner;
import utest.ui.Report;

class TestAll {
  public static function main() {
    var runner = new Runner();
    runner.addCase(new TestReason());
    runner.addCase(new TestPromiseOrValue());
    runner.addCase(new TestPromise());
    Report.create(runner);
    runner.run();
  }
}
