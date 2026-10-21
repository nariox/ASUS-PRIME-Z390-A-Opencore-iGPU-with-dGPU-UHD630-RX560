# Personal notes / TODO

Working notes for this machine (not part of the guide itself).

## To try in BIOS

- [ ] **CFG-Lock**: disable it, then set `AppleXcpmCfgLock` → `false` in
  `config.plist.template` (and re-run `sh OC/applyserialnums.sh`).
  `OC/Tools/ControlMsrE2.efi` is kept so you can check MSR 0xE2 state from
  the UEFI shell (`OC/Tools/OpenShell.efi`).
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
