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
