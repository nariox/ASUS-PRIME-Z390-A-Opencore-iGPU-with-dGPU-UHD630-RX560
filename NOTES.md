# Personal notes / TODO

Working notes for this machine (not part of the guide itself).

## To try in BIOS

- [ ] **CFG-Lock**: disable it, then set `AppleXcpmCfgLock` → `false` in
  `config.plist.template` (and re-run `sh OC/applyserialnums.sh`).
  Now exposed in the picker: **Space → "Control MSR 0xE2 (CFG-Lock)"** to
  check the state; `OpenShell.efi` is also a picker tool if you need the
  full shell.
- [ ] Confirm **DVMT Pre-Allocated ≥ 64 MB** (Sa/IGPU Config) — headless
  UHD 630 still needs a small stolen memory carve-out.
- [ ] **Above 4G Decoding: Enabled** (recommended; more BAR allocation room —
  not strictly required by the RX 6600 since its default BARs fit under 4 GB,
  but it is the recommended state). Check it while in BIOS for CFG-Lock.
- [ ] **ReBAR / Resizable BAR: leave disabled.** `ResizeAppleGpuBars` is now
  `-1` (disabled) to match. If you ever enable ReBAR in BIOS, set
  `ResizeAppleGpuBars` to `0` instead (else Navi may black-screen with an
  8 GB BAR0). (BIOS 1005 likely doesn't expose ReBAR anyway.)
- [ ] VT-d: currently off. **If** ever moving to the AppleBCMWLANCompanion
  Wi-Fi route (see Tahoe notes below), VT-d must be **on** for it to work.

## To-do

- [ ] **Rotate SMBIOS**: the old identifiers were exposed in git history
  (masked now, but clones/caches may still have them). Generate a fresh set
  with GenSMBIOS (platform `iMac19,2`), put all four values in
  `OC/LocalSettings.txt`, run `sh OC/applyserialnums.sh`.
  Note: `USBMap.kext` is keyed to `iMac19,2-XHC` — keep that model.
- [ ] **OpenCore 1.0.7 → 1.0.8** (decided to postpone; do soon).
- [ ] Kext updates when upgrading: WhateverGreen 1.7.1, VirtualSMC 1.3.8,
  AppleALC 1.9.8, AirportBrcmFixup 2.2.1.
- [ ] **Sleep bug = full crash** (2026-10-20). Not just "buggy sleep" —
  the machine crashes. Two hypotheses: TB Display's USB hub adds ports
  (NOTE: the 15-port limit is gone since macOS 11+, so exceeding it
  shouldn't crash Sequoia — port count is a weak suspect), or wake-path /
  USB power-state issue with the TB controller. Plan:
  - [ ] Grab the `*.panic` from `/Library/Logs/DiagnosticReports/` after a
        crash and look at the faulting kext.
  - [ ] Reproduce with TB Display unplugged → isolates TB vs. base system.
  - [ ] Experiment: load `OC/Drivers/TbtForcePower.efi` (kept on disk,
        currently not in `UEFI → Drivers`) — it forces the TB controller
        power state at boot and has helped ALP (Alpine Ridge)
        hotplug/sleep quirks on some boards. (`IOElectrify.kext` was
        removed — superseded by Apple's native Thunderbolt stack since
        Big Sur.)
- [ ] **USB: full remap (do AFTER sleep debugging).** The 15-port limit is
  gone since macOS 11, so all ports can be mapped without risk. Current
  `USBMap.kext` simply omits HS03–06/HS11 (+ SS pairs) — those rear ports
  likely already work, just undescribed (may misreport speed). Don't
  hand-guess HS↔SS mux pairings: re-map every port with **USBToolBox**
  (plug a stick into each one) and keep the personality keyed to
  `iMac19,2` (`iMac19,2-XHC` + `model`), or the map silently stops
  applying.

## If macOS Tahoe (26) ever becomes interesting

Per Dortania's Tahoe notes, current setup breaks in two places:

- **Audio (ALC S1220A)**: AppleHDA.kext is gone from macOS 26, so AppleALC
  stops working for analog outputs. Options: VoodooHDA (lower quality),
  OCLP-style root patching to restore AppleHDA, or move audio to HDMI/DP
  (RX 6600) / USB. Nothing to pre-change on Sequoia.
- **Wi-Fi (BCM4360)**: the IO80211FamilyLegacy injection hack is only known
  to work on macOS 13–15. For 15/26 the maintained route is
  **AppleBCMWLANCompanion** (0xFireWolf) — no root patches, needs **VT-d
  enabled** in BIOS, but "not fully stable or feature complete".
- **SMBIOS**: iMac19,x is unsupported on Tahoe → would need iMac20,x
  (2020 iMac) plus `RestrictEvents.efi` with `revpatch=sbvmm` for OTA
  updates (`SecureBootModel: Disabled` already set ✔).
- Recommendation: stay on Sequoia (supported until ~2027) unless a specific
  Tahoe feature is needed.

## Serial workflow

- `OC/config.plist` = live config (git-ignored). Never commit it.
- `OC/config.plist.template` = committed, identifiers are placeholders.
- After editing the template, run `sh OC/applyserialnums.sh` (from `OC/`)
  to regenerate `config.plist` from `LocalSettings.txt`.

## Intentional deviations from Dortania — do NOT "fix" these

| Setting | Value | Why |
| :--- | :--- | :--- |
| SMBIOS | `iMac19,2` | Dortania's example is 19,1; both valid CFL. USBMap.kext is keyed to `iMac19,2-XHC` — changing model silently un-applies the map. |
| `SecureBootModel` | `Disabled` | Dortania-compliant for 14.4–26.x (security page mandates it for OTA). Here only so nobody "restores" it to `Default` from older advice. |
| `csr-active-config` `ff0f0000` + `amfi=0x80` | SIP partially off | Legacy Broadcom (`IO80211FamilyLegacy`) needs it. Dortania's default kills Wi-Fi. |
| `Kernel→Block: IOSkywalkFamily` = Exclude | with MinKernel gate | Part of the same Wi-Fi recipe (mirrors OpenCore's own Sample). |
| `ExtendBTFeatureFlags` | `true` | Paired with `-btlfxboardid -btlfxbeta -btlfxallowanyaddr`: this BCM4360/20702 adapter needs firmware override flags; keeps Continuity working. Dortania default is NO. |
| `ThirdPartyDrives` | `true` | TRIM for third-party SATA drives; harmless for NVMe. |
| XHC `acpi-wake-type=1` (DeviceProperties) | custom | Original author's USB-wake control; revisit only after the sleep crash is solved (toggle experiment). |
| No `-v` in boot-args | daily-boot choice | Add `-v` temporarily when debugging boot. |
| Canopy theme (Syrah), `Timeout 5`, AudioDxe/CrScreenshotDxe | user preference | Officially supported options. |

## After the next boot (test this round's changes)

- [ ] Boots at all with the pruned EFI + new quirks.
- [ ] USB: System Information → USB shows correct types (HS12 = internal,
      HS13/14 = USB2 rear, others USB3) → confirms the
      `AppleUSBHostMergeProperties` map applies; pair a Bluetooth device.
- [ ] Wi-Fi connects; analog + HDMI audio work; Ethernet works.
- [ ] Sleep test per README (pmset prep first). With `swd_panic=1` a crash
      should now leave a `.panic` in `/Library/Logs/DiagnosticReports/`.

## Sleep crash — still-untried options (from Dortania sleep page)

- Proper Thunderbolt path if TB + sleep both matter: osy's Thunderbolt 3
  fix (https://osy.gitbook.io/hac-mini-guide/details/thunderbolt-3-fix/),
  ThunderboltReset.kext, ThunderboltPkg.
- IRQ conflicts: if crashes persist, rebuild SSDT-HPET properly with
  SSDTTime "FixHPET" — requires the *rename patches* (the old committed
  SSDT-HPET had none and was removed as inert). Do it on the Z390 itself
  (needs a DSDT dump; this Linux box is a different PC — Gigabyte B650M).
- NVMe: check SSD firmware is current (NVMeFix.kext already loaded).
- iGPU RC6: `forceRenderStandby=0` boot-arg if the panic backtrace points
  at iGPU power states.
