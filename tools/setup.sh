#!/bin/bash
M=android/app/src/main/AndroidManifest.xml
sed -i 's#<application#<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/><uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/><application#' $M
