# asus-zenbook-a14-firmware

Firmware for the ASUS Zenbook A14 (UX3407QA, Snapdragon X1P42100) for NixOS: DSP, battery
and patched WCN6855 WiFi (`board-2.bin` rebuilt with this SKU's board data). Everything is
extracted at build time from ASUS' Windows driver EXE, pinned by hash (see `package.nix`;
override `driverExe` to use your own copy). GPU firmware is already in linux-firmware.

```nix
# flake inputs: asus-zenbook-a14-firmware.url = "github:<owner>/asus-zenbook-a14-firmware";
modules = [ asus-zenbook-a14-firmware.nixosModules.default { hardware.asus-zenbook-a14-firmware.enable = true; } ];
```

Include it in your installer ISO config too, so WiFi works during install.
Licence: the packaging is yours to use; the extracted firmware is unfree.
