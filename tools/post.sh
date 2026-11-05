#!/bin/bash
VER=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d '\r')
TAG="v${VER//+/-}"
echo "Publicando $TAG"
gh release delete "$TAG" --yes --cleanup-tag || true
gh release create "$TAG" --title "Radio Mundo $VER" --notes "Actualización $VER" --latest || {
  echo "AVISO: no se pudo crear la versión. Revisa Settings > Actions > General > Workflow permissions."
  exit 0
}
gh release upload "$TAG" REDunix-2026.apk --clobber || {
  echo "AVISO: no se pudo subir el APK a la versión."
  exit 0
}
echo "Versión publicada"
