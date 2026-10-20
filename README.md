# macOS Sequoia on the ASUS PRIME Z390-A (OpenCore, UHD 630 headless + RX 6600)

OpenCore EFI and setup guide for this machine. The iGPU is used headless
(no display output); the AMD dGPU drives all displays.

## Components
- M/B: ASUS PRIME Z390-A (BIOS Ver. 1005)
- CPU: Intel® Core™ i5-9400 Processor
- iGPU: Intel® UHD Graphics 630 (headless)
- dGPU: AMD Radeon RX 6600 8GB
- Lan: Intel® I219V, 1 x Gigabit LAN Controller (IntelMausi)
- WiFi/Bluetooth: BCM4360/BCM20702A0 (legacy Broadcom stack)
- Audio: Realtek® ALC S1220A 8-Channel High Definition Audio (AppleALC)

## Status
Tested on macOS Sequoia 15.7.4 with OpenCore 1.0.7. This guide is NOT
GUARANTEED to work 100% in your conditions.

This EFI targets **macOS 15 (Sequoia) only**: kexts, drivers and config
entries needed only by older macOS versions have been removed.

### Working
- iGPU headless hardware acceleration + RX 6600 display output
- Audio (analog + HDMI/DP), Ethernet, Wi-Fi, Bluetooth
- USB (custom map), Thunderbolt devices when connected at boot

### Not working / known issues
- **Sleep can crash the machine** (under investigation, see debugging notes
  below).
- **Thunderbolt USB devices stop working after sleep** — the Thunderbolt
  Display itself keeps working; the peripherals behind it (camera, audio,
  microphone, USB ports) do not come back. A few seconds with the display
  unplugged from the wall outlet forces macOS to re-enumerate them and
  fixes it until the next sleep. Tested with an Apple Thunderbolt Display
  and a TB3→TB1 adapter. Also tested with the modded ASUS ThunderboltEX3
  firmware (https://github.com/utopia-team/Thunderbolt) — sleep is still
  broken.

### Not tested
- FileVault

## macOS version support (important)
- The BCM4360 Wi-Fi works on macOS 13–15 via the legacy
  `IO80211FamilyLegacy` injection, which requires the (deliberate)
  `csr-active-config` + `amfi=0x80` settings in this config — i.e. SIP
  stays partially disabled. If you don't want that, swap the card.
- **Do not upgrade to macOS 26 (Tahoe) with this setup**: Apple removed the
  components the legacy Broadcom stack needs (Wi-Fi dies) *and*
  `AppleHDA.kext` (analog audio dies). See `NOTES.md` for workarounds.
  Staying on Sequoia is recommended (supported until ~2027).

## BIOS settings
Recommended values (ASUS PRIME Z390-A, BIOS 1005):
- Secure Boot: **Disabled**
- Fast Boot: **Disabled**
- XHCI Hand-off: **Enabled**
- DVMT Pre-Allocated: **64 MB or higher** (needed by the headless iGPU)
- Above 4G Decoding / Resizable BAR: **Disabled** (the config disables bar
  resizing accordingly)
- CFG-Lock: **Disabled** if available (optional; the config currently uses
  `AppleXcpmCfgLock=true` to live with it enabled — if you disable it in
  BIOS, set `AppleXcpmCfgLock` to `false` too)
- Thunderbolt settings: leave at defaults

## Procedure
1. Generate SMBIOS identifiers for **iMac19,2** with
   [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS). Keep the iMac19,2
   model — the USB map (`USBMap.kext`) is keyed to it.
2. Put all four generated values into `OC/LocalSettings.txt`
   (`MLB`, `SystemSerialNumber`, `SystemUUID`, `ROM`; ROM accepts 12 hex
   chars). This file is git-ignored and never committed.
3. Run `sh OC/applyserialnums.sh` — it generates `OC/config.plist` from
   `OC/config.plist.template` with your values injected.
4. Copy the `OC/` folder to your EFI partition and install macOS Sequoia.

## USB
A custom USB map (`OC/Kexts/USBMap.kext`) is included. Some rear ports are
intentionally left unmapped. The BT module of the Wi-Fi card connects to
the internal USB2 header (HS12); HS13/HS14 are the rear USB2 ports:

![PRIME Z390-A - USB port map final](https://user-images.githubusercontent.com/35429874/61994465-821cb780-b0b5-11e9-9d00-b12ed9046afc.jpg)

## Sleep crash debugging notes
- The historical "15-port USB limit" no longer applies on macOS 11+
  (`XhciPortLimit` does nothing on Sequoia), so the extra USB ports added
  by a Thunderbolt display are **unlikely** to be the crash cause.
  Wake-path / USB power-state issues with the Thunderbolt controller are
  the more likely suspect.
- When a sleep crash happens, collect the panic report from
  `/Library/Logs/DiagnosticReports/` (`*.panic`) — the faulting kext in
  the backtrace is the fastest way to narrow it down.
- Useful experiments: reproduce with all Thunderbolt devices unplugged;
  try loading `OC/Drivers/TbtForcePower.efi` (kept on disk, not enabled by
  default).

## Misc
If you need other detailed settings for this ASUS PRIME Z390-A board
(e.g. USB port map sources), please check the release files.

Special thanks to dhckdgjs (initial repository owner), CaseySJ (tonymacx86.com)
and Newlife (x86.co.kr).
