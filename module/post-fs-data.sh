#!/system/bin/sh
# Runs before the USB HAL starts. Puts the patched HAL on a tmpfs (/data is
# nosuid, so SELinux would refuse to start the HAL from there) and bind-mounts
# it over the stock binary. Any failed check leaves the stock HAL in place.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
: > "$LOG"

# Crash guard: if the previous boot never confirmed a healthy patched HAL,
# stay on stock and disable the module.
if [ -f "$MODDIR/.pending" ]; then
  log "previous boot did not confirm the patched HAL; disabling module, using stock"
  rm -f "$MODDIR/.pending"; touch "$MODDIR/disable"; exit 0
fi

[ "$(sha "$HAL")" = "$STOCK" ] || { log "stock HAL hash mismatch (HyperOS update?); skipping"; exit 0; }
[ "$(sha "$MODDIR/hal.patched")" = "$PATCHED" ] || { log "module file corrupted; skipping"; exit 0; }

$NS mkdir -p $TMP
$NS mount -t tmpfs -o mode=0755 tmpfs $TMP || { log "tmpfs mount failed"; exit 0; }
$NS cp "$MODDIR/hal.patched" $TMP/hal
$NS chown root:shell $TMP/hal; $NS chmod 0755 $TMP/hal
$NS chcon $CTX $TMP/hal
if [ "$($NS ls -Z $TMP/hal | cut -d' ' -f1)" != "$CTX" ] || [ "$(sha $TMP/hal)" != "$PATCHED" ]; then
  log "preflight failed (label/hash); using stock"; $NS umount $TMP; exit 0
fi
if $NS grep -q " $TMP .*nosuid" /proc/mounts; then
  log "tmpfs is nosuid; using stock"; $NS umount $TMP; exit 0
fi
$NS mount -o bind $TMP/hal $HAL || { log "bind mount failed; using stock"; $NS umount $TMP; exit 0; }
touch "$MODDIR/.pending"
log "patched HAL bound over $HAL"
