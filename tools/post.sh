#!/bin/bash
VER=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d '\r')
TAG="v${VER//+/-}"
gh release delete "$TAG" --yes --cleanup-tag 2>/dev/null || true
gh release create "$TAG" REDunix-2026.apk --title "Radio Mundo $VER" --notes "Actualización $VER" --latest
