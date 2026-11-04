#!/bin/bash
M=android/app/src/main/AndroidManifest.xml

# --- Permisos ---
sed -i 's#<application#<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/><uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/><uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/><uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/><uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/><uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/><application#' $M

# --- La pantalla se enciende con la alarma ---
sed -i 's#<activity#<activity android:showWhenLocked="true" android:turnScreenOn="true"#' $M

# --- Código nativo del despertador (servicio que reproduce la radio) ---
F=$(find android/app/src/main -name MainActivity.kt | head -1)
DIR=$(dirname "$F")
PKG=$(grep -m1 '^package ' "$F" | awk '{print $2}')
for K in MainActivity AlarmBridge AlarmService AlarmReceiver BootReceiver Updater InstallReceiver; do
  sed "s/PACKAGE_NAME/$PKG/g" tools/android/$K.kt > "$DIR/$K.kt"
done
SNIP="<service android:name=\"$PKG.AlarmService\" android:exported=\"false\" android:foregroundServiceType=\"mediaPlayback\"/><receiver android:name=\"$PKG.AlarmReceiver\" android:exported=\"false\"/><receiver android:name=\"$PKG.InstallReceiver\" android:exported=\"false\"/><receiver android:name=\"$PKG.BootReceiver\" android:exported=\"true\"><intent-filter><action android:name=\"android.intent.action.BOOT_COMPLETED\"/><action android:name=\"android.intent.action.MY_PACKAGE_REPLACED\"/></intent-filter></receiver>"
sed -i "s#</application>#${SNIP}</application>#" $M

# --- Desugaring (lo exige ota_update) ---
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
