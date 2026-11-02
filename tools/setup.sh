#!/bin/bash
M=android/app/src/main/AndroidManifest.xml
sed -i 's#<application#<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/><uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/><uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/><application#' $M

# Desugaring (lo exige ota_update)
G=android/app/build.gradle.kts
if [ -f "$G" ]; then
  if grep -q "compileOptions" "$G"; then
    sed -i 's/compileOptions {/compileOptions {\n        isCoreLibraryDesugaringEnabled = true/' "$G"
  else
    sed -i 's/^android {/android {\n    compileOptions { isCoreLibraryDesugaringEnabled = true }/' "$G"
  fi
  printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n}\n' >> "$G"
else
  G=android/app/build.gradle
  if grep -q "compileOptions" "$G"; then
    sed -i 's/compileOptions {/compileOptions {\n        coreLibraryDesugaringEnabled true/' "$G"
  else
    sed -i 's/^android {/android {\n    compileOptions { coreLibraryDesugaringEnabled true }/' "$G"
  fi
  printf "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'\n}\n" >> "$G"
fi

# Despertador: permisos, receptores y pantalla encendida con la alarma
sed -i 's#<application#<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/><uses-permission android:name="android.permission.VIBRATE"/><uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/><uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/><application#' $M
sed -i 's#</application>#<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/><receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"><intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/><action android:name="android.intent.action.MY_PACKAGE_REPLACED"/><action android:name="android.intent.action.QUICKBOOT_POWERON"/><action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/></intent-filter></receiver></application>#' $M
sed -i 's#<activity#<activity android:showWhenLocked="true" android:turnScreenOn="true"#' $M
