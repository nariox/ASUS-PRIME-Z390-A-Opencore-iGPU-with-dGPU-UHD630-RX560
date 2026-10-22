# Personal notes / TODO

Working notes for this machine (not part of the guide itself).

## To try in BIOS

- [x] **CFG-Lock**: disabled in BIOS, verified with `ControlMsrE2` in the
  picker (2026-10-21). `AppleXcpmCfgLock` set to `false` in the template.
  Both tools show directly in the picker (no Space needed); `OpenShell.efi`
  is there too if you need the full shell.
- [ ] Confirm **DVMT Pre-Allocated ≥ 64 MB** (Sa/IGPU Config) — headless
  UHD 630 still needs a small stolen memory carve-out.
- [x] **Above 4G Decoding: Enabled** — confirmed in BIOS (2026-10-21).
- [x] **ReBAR / Resizable BAR: disabled** — confirmed in BIOS (2026-10-21);
  `ResizeAppleGpuBars` is `-1` (disabled) to match. If it is ever enabled
  in BIOS, set `ResizeAppleGpuBars` to `0` instead (else Navi may
  black-screen with an 8 GB BAR0).
- [ ] VT-d: currently off. **If** ever moving to the AppleBCMWLANCompanion
  Wi-Fi route (see Tahoe notes below), VT-d must be **on** for it to work.

## To-do

- [ ] **Rotate SMBIOS**: the old identifiers were exposed in git history
  (masked now, but clones/caches may still have them). Generate a fresh set
  with GenSMBIOS (platform `iMac19,2`), put all four values in
  `OC/LocalSettings.txt`, run `sh OC/applyserialnums.sh`.
  Note: `USBMap.kext` is keyed to `iMac19,2-XHC` — keep that model.
- [ ] **OpenCore 1.0.7 → 1.0.8** (postponed; verified 2026-10-21: 1.0.8
  has NO USB/XhciPortLimit changes — nothing relevant to us; revisit at
  1.0.9+ or when doing kext updates).
- [ ] Kext updates when upgrading: WhateverGreen 1.7.1, VirtualSMC 1.3.8,
  AppleALC 1.9.8, AirportBrcmFixup 2.2.1.
- [ ] **Sleep bug — status 2026-10-21 (controlled tests)**:
  - Base system (no TB Display): **2 clean sleep/wake cycles, NO crash**
    (Dortania pmset prep + `disablesleep 0` + `hibernatemode 0` + locked
    empty `/var/vm/sleepimage`). Slow-sleeper laggards noted: wifivelocityd
    30 s timeout, apsd/universalcontrol 28 s timeouts (legacy Broadcom +
    `tcpkeepalive 0` — expected).
  - With Apple Thunderbolt Display: **still no crash**, but the TB Display
    does not come back after wake (DP-tunnel retrain failure; known bug).
    Nasty side effect: the login window renders on the dead display —
    workarounds: blind-typed password, unplug display from wall (known
    re-enumeration trick), or drive the machine over SSH during tests.
  - => the "sleep crashes the machine" hypothesis narrows to TB. Also
    spotted `shutdown_stall_*.shutdownStall` reports (17:39, 17:59) —
    worth opening; may name the same device path as the stall cause.
  - [x] **SMOKING GUN (2026-10-21 ~19:11, idle sleep with TB Display)**:
        `pmset -g log` recorded
        `Failure during wake: RP17(AppleThunderboltHAL XHC3) : Some
        drivers failed to handle setPowerState panic`
        — hard hang + silent reboot, no `.panic` (kernel died before the
        writer). Culprit = ThunderboltEX3 (JHL6540) + its XHC3 USB
        controller power-state transition on wake. `AMDRadeonAccelerator
        transaction ... 0xe00002d7` (kIOReturnNotReady) after wake =
        bystander. Countermeasure ladder:
        1. TbtForcePower.efi — TESTED 2026-10-21 evening, FAILED:
           wake hang unchanged (same crash signature, "display doesn't
           work, full system crash soon afterwards") AND the user's TB
           USB devices stopped loading entirely with it enabled.
           Driver disabled again (kept on disk). Upstream FAQ had already
           warned: boot-time power only, "sleep/wake support... strictly
           out of scope". To confirm causality of the USB regression:
           boot without the driver -> TB USB should enumerate again.
        1.5 NEW EXPERIMENT (in progress, user's call): `XhciPortLimit`
            enabled (Kernel→Quirks) + full remap via USBToolBox from a
            Windows Live USB with the TB Display PLUGGED IN, so XHC3's
            ports get an actual USB personality. Hypothesis: XHC3 was
            enumerating unmapped and confusing macOS on wake. XHC3
            class-code hide = HELD until this resolves.
             UPDATE (2026-10-22): remap DONE (UTBMap.kext, commit
             4b24c09) but the boot broke (NVMe "refuses to load").
             Post-mortem: USBToolBox emitted the loader-flavour map
             (`IOClass=USBToolBox`, `OSBundleLibraries=
             com.dhinakg.USBToolBox.kext`) and only the map was
             installed — without the `USBToolBox.kext` loader the map
             can never bind and injection hits an unsatisfied
             dependency. Loader 1.2.0 (RELEASE) added + wired before
             UTBMap; `XhciPortLimit` back to `false` (it was only ever
             needed for macOS-side port discovery — Windows ignores
             it, and a final map makes it pointless; it also carries
             Dortania's data-corruption warning, so removing it
             de-risks the next boot). OC log of the failed boot shows
             boot.efi reached EXITBS (volume + KC fine) — the IONVMe
             asserts / "External Drive Case" lines are kernel-side
             noise or fallout, not an OC problem. To verify after next
             boot: (a) TB Display USB enumerates, (b) the XHC3
             personality `21:0:2` actually binds — it matches on
             `pcidebug 21:0:2` (Windows numbering); macOS renumbers
             PCIe buses, so if ioreg shows no UTB match on XHC3, fix
             the pcidebug key to macOS' numbering.
             RESULT (2026-10-22, commit 81f6baf "New USB working"):
             loader fixed the boot; user renamed the XHC3 personality to
             `XHC3` with 0 ports / `port-count 0`, re-saved the template
             (tabs, ProperTree — semantically verified identical), and
             added a DISABLED `UTBDefault.kext` entry (file intentionally
             not in the repo — OpenCore only requires files for enabled
             entries; it is the emergency no-map fallback switch). The
             zero-port map alone does not disable the XHC3 controller for
             PM purposes — and neither does the class-code hide (driver
             matches by device-id, see ladder step 2 correction); the
             zero-port merge is nonetheless the most effective lever
             available short of ACPI _STA removal.
        2. **APPLIED 2026-10-22, EFFECTIVENESS CORRECTED SAME DAY** — Hide
           XHC3 from macOS (DeviceProperties class-code mask ffffffff on
           `PciRoot(0x0)/Pci(0x1B,0x0)/Pci(0x0,0x0)/Pci(0x2,0x0)/Pci(0x0,0x0)`).
           Formerly HELD because it would kill "the Display's USB behind
           XHC3" — user fact-check 2026-10-22 voids that: XHC3 is the
           USB-C port on the EX3 card itself, dead under the utopia-team
           firmware regardless, and the TB Display's USB devices enumerate
           through ANOTHER path entirely (see TOPOLOGY below).
           VERIFIED IN ioreg (2026-10-22, capture in repo root):
           - class-code injection lands (`class-code = ffffffff`) BUT does
             NOT unbind the driver — AppleUSBXHCIAR matches by device-id
             (`IOPCIPrimaryMatch` literally lists `0x15d48086` = JHL6540
             xHCI) and ignores class-code. XHC3 stays registered/matched/
             active, so it is STILL in the wake PM round. The hide is
             cosmetic; harmless, kept.
           - What actually guts XHC3 is the zero-port UTBMap personality
             (`port-count 0x00` verified merged onto XHC3's driver node):
             controller up, no root ports, minimal wake work.
           - TRUE removal would need the ACPI level: patch XHC3's `_STA`
             to return 0 in SSDT-TB3-RP17 — and iasl can decompile the
             .aml we hold (`iasl -d`), so CaseySJ's source .dsl is NOT
             actually required for this or for the power-save-flag edit.
           AppleThunderboltHAL stays visible either way (hiding it would
           kill the TB Display's DP tunnel). If the sleep re-test still
           fails with zero-port XHC3, next levers in order:
           (a) `_STA=0` on XHC3 via decompiled+recompiled SSDT,
           (b) `power-save` flag in ThunderboltConfig (same decompile),
           (c) BIOS GPIO-force-power, (d) `pmset sleep 0`.

           TOPOLOGY (2026-10-22 ioreg, verified): the TB Display's USB is
           NOT behind XHC3. Path: RP17 → UPSB → DSB1 → Pericom
           PI7C9X440SL PCIe-USB2 EHCI bridge (`pci12d8,400f`, driver
           `AppleUSBEHCIPI7C9X440SL`, `pcidebug 21:0:2` — reached through
           the TB PCIe tunnel, its own root hub) → Display's internal
           USB2 hub → Display Audio, FaceTime HD Camera (Display),
           downstream USB ports; display brightness control rides this
           same USB link. The ORIGINAL UTBMap personality named `21:0:2`
           was labeling THIS Pericom bridge (4 ports, connector 255) —
           NOT XHC3; the user's rename-to-`XHC3`+zero correctly hit the
           real XHC3 instead (IONameMatch `XHC3`). The Pericom needs no
           personality (generic EHCI enumeration, confirmed working with
           audio+camera active in the capture). NOTHING must be done to
           preserve Display audio/camera/brightness — the current config
           already leaves that branch untouched.
        3. BIOS GPIO-force-power option IF exposed (Gigabyte calls it
           "GPIO3 Force PWR"; ASUS PRIME Z390-A may not expose anything
           similar) — keeps card powered through sleep at platform level.
        What SSDT-TB3-RP17.aml actually declares (from strings disasm):
        CaseySJ Alpine Ridge EX3 tree under `\_SB.PCI0.RP17`: PXSX, NHI0
        (+ThunderboltDROM/ThunderboltConfig `power-save`, linkDetails),
        DSB1/DSB2, XHC3 (+AAPL,current-in-sleep etc.), RHUB/HS01/SSP1
        USB-C port — and `_PRW` (wake-from-sleep source) on RP17, PXSX,
        NHI0, DSB1, DSB2, XHC3 and RHUB, i.e. the whole failing subtree
        is wake-enabled. Built-in XHC (PciRoot(0x0)/Pci(0x14,0x0)) has
        `acpi-wake-type=1` in DeviceProperties; XHC3 has no entry yet.
        4. Practical fallback: `pmset sleep 0` (never idle-sleep; manual
           sleep only if it proves safe).
  - [x] `UEFI → Drivers`: TbtForcePower.efi enabled (2fdc305) then
        DISABLED again same evening — see ladder step 1 (failed + suspect
        for TB-USB regression).
        (`IOElectrify.kext` stays removed — superseded by Apple's native
        Thunderbolt stack since Big Sur.)
  - [ ] Dortania's two TB links are now assessed and exhausted:
        osy86/ThunderboltReset = "Reset and disable the Thunderbolt ICM"
        (ICM-managed controllers only; EX3/Alpine Ridge has no ICM →
        not applicable); al3xtjames/ThunderboltPkg = firmware-update
        tools + TbtForcePower itself (FAQ: wake explicitly out of scope).
        Remaining real paths: osy TB3-fix-style surgery (XHC3 hide /
        `power-save` flag — ladder above) or disable TB.
  - [x] **PANIC REPORT FINALLY CAUGHT (2026-10-22, saved as
        `deathlog.txt` in this repo)**: `Wake transition timed out
        after 180 seconds while calling power state change callbacks.
        Suspected bundle: com.apple.iokit.IOThunderboltFamily` —
        backtrace `IOThunderboltController::startScan ← ::wake ←
        ::setPowerState` (IOThunderboltFamily 9.3.3, Sequoia
        24G517). The TB controller's wake-time topology scan blocks
        on its work-loop gate and never completes; the kernel gives
        the driver set 180 s and then panics — i.e. the "silent
        reboot" was actually a 3-minute hang ending in a panic that
        `swd_panic=1` finally let us capture. Confirms the
        `RP17(AppleThunderboltHAL XHC3)` pmset line at driver level:
        the hang is inside Apple's TB family, not USB-family
        bookkeeping. Countermeasure ladder unchanged; if the USB
        remap (step 1.5) doesn't change the failure, the
        `power-save`-flag surgery and XHC3 hide are the next levers
        with hard evidence behind them.
- [ ] **USB: full remap (do AFTER sleep debugging).** CORRECTION
  (2026-10-21, verified against OC 1.0.7 Configuration.pdf): the 15-port
  limit is NOT gone — it is enforced per controller via the locationID
  bit format, "the only valid solution is to limit the amount of used
  ports to 15". Current `USBMap.kext` enables exactly 15 ports
  (HS01/02/07–10/12–14 + SS01/02/07–10) — a full remap must therefore
  spend a 15-port budget: drop HS03–06/HS11 or their SS partners
  deliberately, pick the 15 ports that actually get used, and let
  USBToolBox bind the HS↔SS mux pairs (don't hand-guess them). Keep the
  personality keyed to `iMac19,2` (`iMac19,2-XHC` + `model`), or the map
  silently stops applying. UPDATE (2026-10-21): remap is starting NOW
  from a Windows Live USB + USBToolBox, TB Display plugged in so XHC3
  gets mapped too; `XhciPortLimit` enabled meanwhile (experiment step
  1.5). After remap: replace `USBMap.kext` with the USBToolBox output
  (and its config entry), then decide whether `XhciPortLimit` goes back
  to `false`.
  DONE (2026-10-22): `UTBMap.kext` (USBToolBox 1.1 map format) is the
  live map — XHC gets 15 ports (HS01–09 + SS01–06, mux pairs implied
  by index+0x10, `port-count 0x1a`), XHC3 gets 4 internal PRT ports;
  `USBMap.kext` disabled (kept on disk as fallback). The
  `iMac19,2-XHC`/`model` keying requirement is RETIRED — UTBMap
  matches by ACPI name (`IONameMatch XHC`) + `pcidebug` property, not
  by SMBIOS model, so the map survives SMBIOS changes. `XhciPortLimit`
  is back to `false`. NOTE: this map format REQUIRES the
  `USBToolBox.kext` loader (added, v1.2.0) — map and loader must
  always be updated/removed together, and the legacy `UTBDefault.kext`
  from the release zip must NOT be added (it is the no-map fallback).

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
- [x] Sleep test per README: **base system sleeps/wakes cleanly** (2026-10-21,
      no `.panic`). Remaining failure is TB Display wake only — see the
      sleep-bug section above.

## Sleep crash — still-untried options (from Dortania sleep page)

- Proper Thunderbolt path if TB + sleep both matter: osy's Thunderbolt 3
  fix (https://osy.gitbook.io/hac-mini-guide/details/thunderbolt-3-fix/);
  for this machine the relevant knobs are inside the already-loaded
  `SSDT-TB3-RP17.aml` (ThunderboltConfig `power-save`, per-device `_PRW`)
  and DeviceProperties on XHC3 — see the countermeasure ladder above.
- IRQ conflicts: if crashes persist, rebuild SSDT-HPET properly with
  SSDTTime "FixHPET" — requires the *rename patches* (the old committed
  SSDT-HPET had none and was removed as inert). Do it on the Z390 itself
  (needs a DSDT dump; this Linux box is a different PC — Gigabyte B650M).
- NVMe: check SSD firmware is current (NVMeFix.kext already loaded).
- iGPU RC6: `forceRenderStandby=0` boot-arg if the panic backtrace points
  at iGPU power states.
