# NCM USB tethering fix for POCO F8 Ultra (HyperOS 4)

A KernelSU/Magisk module that makes USB tethering on the POCO F8 Ultra
(`myron`, SM8850, HyperOS 4.0.1 / Android 17) use **CDC-NCM**, which macOS
supports natively with no driver, and fixes the HyperOS bugs that otherwise
break it.

## What's wrong on stock

1. **Tethering uses RNDIS.** Android's tethering service is set to RNDIS,
   which macOS doesn't support. Android has an NCM mode, but it isn't enabled.
2. **The USB HAL races itself when NCM is turned on.** Xiaomi's change to
   `android.hardware.usb.gadget-service.qti` (`addFunctionsFromPropString`)
   sets `vendor.usb.config.ncm=0` and then immediately links
   `ncm.gs6` into the gadget. `init.qcom.usb.rc` reacts to `ncm=0` with
   `rmdir ncm.gs6`. When the two collide, the kernel logs
   `refcount_t: addition on 0; use-after-free` in `configfs_symlink`, the
   HAL fails, and Settings shows "USB tethering error".
3. **The Settings switch can't see NCM.** `MiuiTetherSettings` takes the USB
   interface patterns from `AmlMiuiWifiService.getTetherableRegexs`, which reads
   `android.miui:array/config_tether_usb_regexs` (`usb\d`, `rndis\d`). `ncm0`
   matches neither, so the switch stays off while tethering runs, and turning it
   off ends in a rejected duplicate start request.

## What the module does

| Problem | Fix |
|---|---|
| 1 | `service.sh` sets `settings put global tether_force_usb_functions 1` at every boot (NCM). `uninstall.sh` removes it. |
| 2 | At install, `customize.sh` copies **this phone's own** HAL, checks its SHA-256, and replaces the `bl SetProperty` at file offset `0xf9bc` with a `nop` (4 bytes), then checks the result hash. At boot, `post-fs-data.sh` puts it on a tmpfs (`/data` is `nosuid`, which would block the SELinux domain change), labels it `vendor_hal_usb_qti_exec`, and bind-mounts it over the stock HAL. |
| 3 | A static resource overlay (`overlay/`) for `com.miui.rom` that adds `ncm\d`. It's installed as `/product/overlay/MiuiProcessResOverlay.apk`, because `libmiui_runtime.so` only loads MIUI overlays from a fixed list of paths, and that one is unused on this ROM. |

No Xiaomi binaries are in this repo.

### Safety checks

- Install aborts unless the HAL hash is the exact build this was made for:
  stock `030896a0a46e1fff3a136e565360474155c1e99ce70ec385f5a199f749785048`,
  patched `673f0d0e86b9afcbf0c2299cda85a43108f71ea515bedb0a221f8a997751c2d8`.
- Boot checks the hashes, the SELinux label and the tmpfs mount flags. If any
  check fails, the stock HAL is used.
- Crash guard: if a boot doesn't confirm the patched HAL is running, the module
  removes the bind mount and disables itself, so the HAL can't loop into
  Android's rescue reboot.
- Install aborts if the ROM ever ships a real `MiuiProcessResOverlay.apk`.
- Log: `/data/adb/modules/poco_ncm_tether_fix/last.log`

## Build and install

```bash
./build.sh            # zips module/ into dist/poco-ncm-tether-fix.zip
./build.sh --overlay  # also rebuilds and signs the overlay APK
```

Install the zip from the KernelSU (or Magisk) app and reboot. Tested on
KernelSU 4.3.0 with the NoMount meta-module.

## Mac side

If the Mac doesn't get an address while tethering is on, check that a
"POCO F8 Ultra" service is listed in System Settings → Network. If not, add it,
or run:

```bash
networksetup -createnetworkservice "POCO F8 Ultra" "POCO F8 Ultra"
```

Download speed is then limited by the mobile network, not USB 2.

## Windows

- **Windows 11:** the built-in NCM driver loads on its own.
- **Windows 10 22H2:** the driver (`UsbNcm.sys`) is included but isn't picked
  automatically. Tested and working after picking it once:
  1. Turn USB tethering on with the phone plugged in.
  2. In Device Manager, open the phone's unknown device, then choose
     **Update driver → Browse my computer → Let me pick from a list** →
     **Network adapters → Microsoft → UsbNcm Host Device**.
  3. Windows usually remembers this. If the phone is plugged into a different
     USB port, you may need to repeat it.
- **Alternative:** Windows also supports RNDIS natively. For a Windows-only
  session, `su -c settings put global tether_force_usb_functions 0` switches
  the phone back to RNDIS until the next reboot.

## After a HyperOS update

The HAL hash will most likely change. The module then skips the HAL patch
(tethering still uses NCM, but the race is back) until it's rebuilt for the new
HAL: find the same `SetProperty(vendor.usb.config.ncm, "0")` call, update
`OFF`, `STOCK` and `PATCHED`.

## Removing

Remove the module in KernelSU and reboot. USB tethering goes back to RNDIS.
