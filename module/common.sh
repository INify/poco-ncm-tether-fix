HAL=/vendor/bin/hw/android.hardware.usb.gadget-service.qti
STOCK=030896a0a46e1fff3a136e565360474155c1e99ce70ec385f5a199f749785048
PATCHED=673f0d0e86b9afcbf0c2299cda85a43108f71ea515bedb0a221f8a997751c2d8
CTX=u:object_r:vendor_hal_usb_qti_exec:s0
TMP=/mnt/poco_ncm_fix
NS="nsenter -t 1 -m --"
LOG=$MODDIR/last.log
log() { echo "$(date '+%F %T') $*" >> "$LOG"; echo "<6>poco_ncm_fix: $*" > /dev/kmsg; }
sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
