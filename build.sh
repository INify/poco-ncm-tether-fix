#!/usr/bin/env bash
# Builds the flashable module zip. Pass --overlay to rebuild the Settings
# overlay APK first (needs apktool, keytool, jarsigner, python3).
set -euo pipefail
cd "$(dirname "$0")"
OUT=dist/poco-ncm-tether-fix.zip
APK=module/system/product/overlay/MiuiProcessResOverlay.apk

if [ "${1:-}" = "--overlay" ]; then
  W=$(mktemp -d)
  apktool b overlay -o "$W/unsigned.apk"
  [ -f overlay-key.jks ] || keytool -genkeypair -keystore overlay-key.jks -storepass overlay -keypass overlay \
      -alias overlay -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=ncm tether overlay"
  jarsigner -keystore overlay-key.jks -storepass overlay -sigalg SHA256withRSA -digestalg SHA-256 \
      "$W/unsigned.apk" overlay >/dev/null
  # 4-byte align uncompressed entries (resources.arsc) like zipalign
  python3 - "$W/unsigned.apk" "$APK" <<'PY'
import sys, zipfile
src = zipfile.ZipFile(sys.argv[1]); out = zipfile.ZipFile(sys.argv[2], "w")
for i in src.infolist():
    zi = zipfile.ZipInfo(i.filename, i.date_time)
    zi.compress_type = i.compress_type; zi.external_attr = i.external_attr
    if zi.compress_type == zipfile.ZIP_STORED:
        off = out.fp.tell() + 30 + len(zi.filename.encode())
        zi.extra = b"\0" * ((4 - off % 4) % 4)
    out.writestr(zi, src.read(i.filename))
out.close()
PY
  rm -rf "$W"
  echo "rebuilt $APK"
fi

mkdir -p dist
rm -f "$OUT"
(cd module && zip -qr -X "../$OUT" . -x '.*')
echo "built $OUT"
