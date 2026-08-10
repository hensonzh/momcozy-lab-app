package com.momcozymai.momcozy_flutter_app;

import android.Manifest;
import android.content.Intent;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

@RunWith(FlutterTestRunner.class)
public class MotionPoseReleaseTest {
  @Rule
  public final ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<>(MainActivity.class, true, false) {
        @Override
        protected Intent getActivityIntent() {
          return new Intent(
                  InstrumentationRegistry.getInstrumentation().getTargetContext(),
                  MainActivity.class)
              .putExtra("momcozy.flutter.extra.INTEGRATION_TEST", true);
        }

        @Override
        protected void beforeActivityLaunched() {
          InstrumentationRegistry.getInstrumentation()
              .getUiAutomation()
              .grantRuntimePermission(
                  InstrumentationRegistry.getInstrumentation()
                      .getTargetContext()
                      .getPackageName(),
                  Manifest.permission.CAMERA);
          super.beforeActivityLaunched();
        }
      };
}
