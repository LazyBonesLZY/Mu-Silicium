# BdsDxe vs QcomBds — static analysis (marble)

Date: 2026-10-19 Asia/Shanghai. Gate: ≥90% static only.

## Stock evidence (`extracted/fw-uefi/`)
- Nested DXE FV (`notes/stock-re/carved/nested.fv`, gunzip from `uefi.img`) VolInfo UI list includes **`QcomBds`** and **`BDS_Menu.cfg`**, not `BdsDxe`.
- `Binaries/marble/QcomPkg/Drivers/QcomBds/QcomBds.inf`: `MODULE_TYPE = DXE_DRIVER`, `FILE_GUID = 5A50AA81-C3AE-4608-A0E3-41A2E69BAF94`.
- Strings in `QcomBds.efi` include `DefaultBDSBootApp` (consumes PlatCfg key now embedded via `RAW.inc` GUID `DDE58710-…`).
- GUID search in nested FV used to carve PE and compare to Device-Binaries (see notes/stock-re/carved/).

## Silicium / Mu evidence
- `rg QcomBds Platforms/**/DXE.inc` → **0** devices.
- `rg BdsDxe.inf Platforms/**/DXE.inc` → **85** devices (including marble, pong, venus, alioth).
- `Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc` builds `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf` linked with `PlatformBootManagerLib|SiliciumPkg/Library/BootManagerLib/BootManagerLib.inf` (calls `UpdateAcpiTables()` — required for marble ACPI USB hooks already enabled).
- marble `Include/DXE.inc` line ~55: `BdsDxe.inf` (same pattern as pong Linux-boot ✅ ports).

## Decision (≥95%): **do NOT replace BdsDxe with QcomBds**
| Claim | Conf. | Why |
|-------|------|-----|
| Stock Android FV uses QcomBds | ≥95% | VolInfo UI + INF in Device-Binaries |
| Mu-Silicium marble must keep BdsDxe | ≥95% | Universal Silicium pattern (85/85); BootManagerLib/ACPI update path bound to BdsDxe in `SiliciumPkg.dsc.inc` |
| Swapping to QcomBds alone would match stock | ~40% | Would diverge from every Silicium port; risk breaking `UpdateAcpiTables` / DT boot manager integration without a proven dual-BDS recipe |
| Adding QcomBds *alongside* BdsDxe | &lt;50% | No Silicium precedent; interaction undefined → **no change** |

`DefaultBDSBootApp=LinuxLoader` is already in FV via stock-identical `uefiplat.cfg` embed (`b1e69db`). Linux path remains: **BdsDxe + BootManagerLib + DtPlatformDxe + FdtBlob** (Silicium), not QcomBds.

## Launch-hook precedent for `DefaultChargerApp` (this pass, docs-only)

The stock launch consumer is **only** the prebuilt `QcomBds.efi`
(`strings -a`: `DefaultChargerApp`, `EnableChargerPdSupport`,
`Failed to launch default charger app, status: %r`). It has **no buildable
source** in this tree and **0/85** `Platforms/**/DXE.inc` enable it. The two BDS
libraries marble actually links contain **0** charger references and **0**
application `LoadImage`/`StartImage` calls:

- `PlatformBootManagerLib` = `Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/BootManager.c`
  (`SiliciumPkg.dsc.inc:238`, bound to `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf`).
- `DeviceBootManagerLib` = `Silicon/Qualcomm/QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c`
  (`QcomPkg.dsc.inc:36`); its `AfterConsole` only signals `gUsbControllerInitGuid`/`gSdCardInitGuid`.

Across `Silicon/`+`Common/`, **6** files register a `ReadyToBoot` handler; **0**
mention the charger and **0** call `LoadImage`/`StartImage`. The only one in
`Silicon/` is `KernelErrataPatcherLib.c:191` (kernel errata, not an app launch).

| Candidate hook | Proven Silicium precedent? | Verdict |
|----------------|:--------------------------:|---------|
| Swap/add `QcomBds` | 0/85; prebuilt-only; risks the ACPI/DT BDS path | **reject** (unchanged) |
| `ReadyToBoot` handler that launches `QcomChargerApp` | 0 handlers; no ≥90% template | **not invented** |
| `PlatformBootManagerAfterConsole`/`PriorityBoot` app launch | 0 precedents | **not invented** |
| Boot Manager manual launch of the app | `BdsDxe` built-in | available, not automatic |

**Decision:** keep `BdsDxe`, **no** `QcomBds`, and **do not invent a launch
hook**. The residual is documented only ([`usb-pd-re.md`](usb-pd-re.md) §6/§6.1,
[`pd-track.md`](pd-track.md)); no `Status.md` flip.

## Remaining Status gaps (static posture)
| Gap | Static posture | Next ≥90% action? |
|-----|----------------|-------------------|
| USB Host | Patched UsbConfig + ACPI SDT + XHCI stack present | None without device; no further static knob found |
| USB PD | ChargerPD/pmic-glink stack + QcomChargerCfg present; stock `QcomChargerApp` now embedded + PILDxe enabled (stock-RE-first, no FDF guessing) | **None for auto-launch:** launch-hook precedent search found **0/85** Silicium `DefaultChargerApp` consumers and 0 app-launch hooks; `BdsDxe` kept, no `QcomBds`, no invented hook; residual in `usb-pd-re.md` §6.1 + `pd-track.md` |
| Windows Boot | ACPI+DT dual; no stock DSDT | None (stock has 0 DSDT) |
| Linux Boot | DT + stock uefiplat/BDS_Menu embedded; keep BdsDxe | **No Bds swap** |
