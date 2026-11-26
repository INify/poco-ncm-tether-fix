#!/system/bin/sh
# Builds the patched HAL from this phone's own stock HAL, so no Xiaomi binary
# is shipped. Only the exact build below is accepted.
. "$MODPATH/common.sh"
OFF=63932          # 0xf9bc: bl SetProperty("vendor.usb.config.ncm","0")
OUT="$MODPATH/hal.patched"

ui_print "- Checking USB gadget HAL"
CUR=$(sha256sum "$HAL" | cut -d' ' -f1)
if [ "$CUR" = "$STOCK" ]; then
  cp "$HAL" "$OUT"
  # replace the call with NOP (1f 20 03 d5)
  printf '\037\040\003\325' | dd of="$OUT" bs=1 seek=$OFF conv=notrunc 2>/dev/null
elif [ "$CUR" = "$PATCHED" ]; then
  # Module already active: /vendor shows the patched copy.
  cp "$HAL" "$OUT"
else
  ui_print "! This phone's HAL is a different build: $CUR"
  abort "! Not installing (a HyperOS update probably changed it)"
fi
[ "$(sha256sum "$OUT" | cut -d' ' -f1)" = "$PATCHED" ] || abort "! Patching failed, result hash does not match"
ui_print "- Patched HAL built from this phone's HAL"

# The Settings overlay uses a path Xiaomi's framework loads by fixed name.
if [ -e /product/overlay/MiuiProcessResOverlay.apk ] && [ ! -e /data/adb/modules/poco_ncm_tether_fix/system/product/overlay/MiuiProcessResOverlay.apk ]; then
  abort "! /product/overlay/MiuiProcessResOverlay.apk already exists on this ROM; not overriding it"
fi

rm -f "$MODPATH/.pending" "$MODPATH/disable"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
ui_print "- OK. Reboot to apply. Log: /data/adb/modules/poco_ncm_tether_fix/last.log"
