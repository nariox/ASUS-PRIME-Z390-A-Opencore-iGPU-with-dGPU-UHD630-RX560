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
- **Sleep is broken — disable it.** A few seconds after waking the
  machine freezes/crashes, **even with no Thunderbolt device
  connected**: the ThunderboltEX3 card alone triggers it, and unplugging
  the Thunderbolt cable does not make sleep safe. Nothing fixed it —
  Dortania `pmset` sleep hygiene, the modded ASUS ThunderboltEX3
  firmware (https://github.com/utopia-team/Thunderbolt), force-power
  drivers, a full USB remap, SSDT power-state surgery. Panic captures
  and the full debugging history are in `NOTES.md`.
  Workaround: `sudo pmset -a sleep 0` (display sleep is unaffected and
  stays safe).
- With an Apple Thunderbolt Display attached, wake additionally fails in
  one of two ways: the panel stays dark (the login window renders on the
  dead screen), or the Display returns while its built-in peripherals
  (camera, audio, microphone, USB ports) stay dead. A few seconds with
  the display unplugged from the wall outlet forces macOS to
  re-enumerate the chain and fixes it until the next wake.

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
Recommended values from the Dortania guide (ASUS PRIME Z390-A, BIOS 1005):
- Secure Boot: **Disabled**
- Fast Boot: **Disabled**
- CSM (Compatibility Support Module): **Disabled** — with it on you'll see
  GPU errors/stalls
- XHCI Hand-off: **Enabled**
- DVMT Pre-Allocated: **64 MB or higher** (needed by the headless iGPU)
- Above 4G Decoding: **Enabled** (recommended — lets firmware place the GPU's
  MMIO BARs above the 4 GB boundary, which macOS handles fine)
- Re-Size BAR Support (Resizable BAR): **Disabled** — macOS gains nothing
  from it, and the config matches with `ResizeAppleGpuBars: -1`. If you do
  enable it anyway, set `ResizeAppleGpuBars` to `0` so OpenCore resizes the
  bar back down, or the RX 6600 may black-screen
- VT-d: **Disabled** (the config keeps `DisableIoMapper=true` as a safety
  net either way)
- CFG-Lock: **Disabled** (verified with the `ControlMsrE2` picker tool) —
  the config matches with `AppleXcpmCfgLock=false`; if you re-enable
  CFG-Lock in BIOS, set it back to `true`
- TPM / Intel Platform Trust / Intel SGX: **Disabled**
- Serial / Parallel ports: **Disabled** if present
- Wake on LAN / Wake on USB: **Disabled** (common cause of sleep/wake
  loops; keep Wake on Bluetooth only if you wake the Mac with a BT device)
- Thunderbolt settings: leave at defaults (sleep with the TBEX3 card
  installed crashes regardless — see known issues above)
- OS type: **Windows 8.1/10 UEFI Mode**; SATA Mode: **AHCI**

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

> [!NOTE]
> The OpenCore picker always shows the two tools: `OpenShell` (UEFI shell)
> and `ControlMsrE2` (checks whether CFG-Lock is enabled). Other auxiliary
> entries, such as macOS Recovery, stay hidden — press **Space** to reveal
> them (`HideAuxiliary` is on by design, per Dortania).

## USB
A custom USB map (`OC/Kexts/USBMap.kext`) is included. Some rear ports are
intentionally left unmapped. The BT module of the Wi-Fi card connects to
the internal USB2 header (HS12); HS13/HS14 are the rear USB2 ports:

![PRIME Z390-A - USB port map final](https://user-images.githubusercontent.com/35429874/61994465-821cb780-b0b5-11e9-9d00-b12ed9046afc.jpg)

## Misc
If you need other detailed settings for this ASUS PRIME Z390-A board
(e.g. USB port map sources), please check the release files.

Special thanks to dhckdgjs (initial repository owner), CaseySJ (tonymacx86.com)
and Newlife (x86.co.kr).
