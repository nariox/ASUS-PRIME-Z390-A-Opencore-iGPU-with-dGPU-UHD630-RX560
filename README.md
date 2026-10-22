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
- **Thunderbolt + sleep is broken in two flavors** (tested with an Apple
  Thunderbolt Display via a TB3→TB1 adapter): after wake, either the
  Display itself stays dark (system is fine — but the login window
  renders on the dead panel), or the Display comes back while its
  built-in peripherals (camera, audio, microphone, USB ports) stay dead.
  A few seconds with the display unplugged from the wall outlet forces
  macOS to re-enumerate the whole chain and fixes it until the next
  sleep. Also tested with the modded ASUS ThunderboltEX3 firmware
  (https://github.com/utopia-team/Thunderbolt) — still broken.
- **Sleep crash**: earlier builds crashed during sleep, but with the
  Dortania `pmset` settings below the base system now sleeps and wakes
  cleanly (verified 2026-10-21; no `.panic` produced). The crash re-armed
  itself once with the Display attached and `pmset -g log` caught it:
  `Failure during wake: RP17(AppleThunderboltHAL XHC3) : Some drivers
  failed to handle setPowerState` — a hard hang in the ThunderboltEX3
  wake path. `TbtForcePower.efi` was tried and reverted (it only forces
  power-on at boot; and with it enabled the Display's USB devices stopped
  enumerating) — see the debugging notes below for the current experiment
  queue.

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
- Thunderbolt settings: leave at defaults (for TB-vs-sleep debugging see the
  notes below)
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

## Sleep crash debugging notes
Dortania's sleep guide (https://github.com/dortania/OpenCore-Post-Install
/universal/sleep.md) is the playbook here. Notes specific to this machine:

- `swd_panic=1` is now in boot-args: when sleep fails it forces a real
  kernel panic **with a log** instead of a silent reboot. Reproduce a crash,
  then read the report in `/Library/Logs/DiagnosticReports/` (`*.panic`) —
  the faulting kext in the backtrace is the fastest way to narrow it down.
  **CAUGHT (2026-10-22, saved as `deathlog.txt` in this repo):** `Wake
  transition timed out after 180 seconds while calling power state change
  callbacks. Suspected bundle: com.apple.iokit.IOThunderboltFamily`, backtrace
  `IOThunderboltController::startScan ← ::wake ← ::setPowerState`. On wake,
  Apple's Thunderbolt family starts its topology scan of the EX3 and the scan
  never completes — the kernel waits 180 s on the power-state callback, then
  panics. The "silent reboot" was a 3-minute hang all along, and the hang is
  inside the TB wake path itself, exactly what the `RP17(AppleThunderboltHAL
  XHC3)` pmset line had been pointing at.
- Before testing, match Dortania's prep (disables hibernation/Power Nap and
  the network/wake timers that mask sleep bugs; the sleepimage lock
  prevents a hibernation image from ever being written mid-test):
  ```
  sudo pmset -a disablesleep 0 hibernatemode 0 autopoweroff 0 standby 0 powernap 0 proximitywake 0 tcpkeepalive 0 womp 0
  sudo rm -f /var/vm/sleepimage && sudo mkdir -p /var/vm/sleepimage && sudo chflags uchg /var/vm/sleepimage
  ```
  Check with `pmset -g`: `SleepDisabled` must be `0` (it silently re-arms
  on some setups and blocks all sleep). Sleep manually (Apple menu) or
  with `pmset sleepnow`; `pmset -g log | grep -E 'Sleep|Wake|Denied'`
  shows each attempt and its outcome.
- The "15-port USB limit" is real on Sequoia (contrary to earlier folklore
  in this README): per OpenCore 1.0.7's Configuration.pdf the limit is
  baked into the USB locationID format ("the only valid solution is to
  limit the amount of used ports to 15") and `XhciPortLimit` is still
  maintained. It applies **per controller**: our USBMap enables exactly 15
  ports on the built-in XHC, while the Thunderbolt Display's hub hangs off
  a downstream port of the separate XHC3 controller and consumes no root
  ports — so port count is still not the crash mechanism. Wake-path /
  USB power-state issues with the Thunderbolt controller are. Dortania
  is blunt about Thunderbolt: working TB
  + working sleep usually means *patching TB properly* (osy's Thunderbolt 3
  fix: https://osy.gitbook.io/hac-mini-guide/details/thunderbolt-3-fix/ ,
  ThunderboltReset) or disabling TB during install/debug.
- Useful experiments, in order of effort:
  1. **done, pending re-test**: full USB remap with USBToolBox from a Windows
     Live USB, with the Thunderbolt Display plugged in so the XHC3 (EX3)
     ports are mapped too (`UTBMap.kext`: 15 XHC ports + 4 XHC3 ports). The
     map format needs the `USBToolBox.kext` loader — install both together
     (`XhciPortLimit` is NOT needed with the finished map and is back to
     `false`). Hypothesis under test: XHC3 enumerating with no USB
     personality confused macOS during wake — verdict = whether the
     `RP17(AppleThunderboltHAL XHC3)` failure line survives a mapped XHC3;
  2. SSDT surgery on `SSDT-TB3-RP17.aml`: clear the `power-save` flag in
     its `ThunderboltConfig` so macOS never deep-powers the controller
     (needs CaseySJ's source .dsl from the tonymacx86 EX3 thread — we
     only hold the compiled .aml);
  3. hide XHC3 from macOS via DeviceProperties (`class-code ff ff ff ff`
     on
     `PciRoot(0x0)/Pci(0x1B,0x0)/Pci(0x0,0x0)/Pci(0x2,0x0)/Pci(0x0,0x0)`
     — verified from ioreg `pcidebug 11:0:0`): removes XHC3 from the
     failing wake set, but the Display's USB hub / camera / audio stop
     working **always**, not just after sleep — HELD in reserve until
     the remap experiment resolves;
  4. if the panic backtrace implicates the iGPU power states, try
     `forceRenderStandby=0` in boot-args (CFL iGPU RC6 quirk from the
     Dortania sleep page).

## Misc
If you need other detailed settings for this ASUS PRIME Z390-A board
(e.g. USB port map sources), please check the release files.

Special thanks to dhckdgjs (initial repository owner), CaseySJ (tonymacx86.com)
and Newlife (x86.co.kr).
