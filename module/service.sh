#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common.sh"
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
settings put global tether_force_usb_functions 1

[ -f "$MODDIR/.pending" ] || exit 0
sleep 10
PID=$(pidof android.hardware.usb.gadget-service.qti)
if [ -n "$PID" ] && [ "$(sha /proc/$PID/exe)" = "$PATCHED" ]; then
  rm -f "$MODDIR/.pending"; log "patched HAL running (pid $PID)"
else
  # Leave .pending so the next boot stays on stock; drop the bind now so
  # init's next restart of the HAL uses the stock binary.
  log "patched HAL not running; reverting to stock"
  $NS umount $HAL; touch "$MODDIR/disable"; rm -f "$MODDIR/.pending"
fi
