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

## Remaining Status gaps (static posture)
| Gap | Static posture | Next ≥90% action? |
|-----|----------------|-------------------|
| USB Host | Patched UsbConfig + ACPI SDT + XHCI stack present | None without device; no further static knob found |
| USB PD | ChargerPD/pmic-glink stack + QcomChargerCfg present; stock `QcomChargerApp` now embedded + PILDxe enabled (stock-RE-first, no FDF guessing) | None for auto-launch: `BdsDxe` does not string-match `DefaultChargerApp`; residual documented in `usb-pd-re.md` |
| Windows Boot | ACPI+DT dual; no stock DSDT | None (stock has 0 DSDT) |
| Linux Boot | DT + stock uefiplat/BDS_Menu embedded; keep BdsDxe | **No Bds swap** |
