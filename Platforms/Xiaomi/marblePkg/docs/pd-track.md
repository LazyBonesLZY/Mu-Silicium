# USB PD track — milestone and decision record (marble UEFI)

Date: 2026-10-19 Asia/Shanghai (CST, UTC+8). **STATIC. Docs-only. No on-device.
No `Status.md` flip. No `QcomBds`. No invented launch hook.**

Track: FULLCHAIN §1 PD P0 (USB PD honesty). This file is the milestone/decision
record for the PD track; the deep evidence lives in
[`usb-pd-re.md`](usb-pd-re.md), with the BDS decision in
[`bds-qcombds-analysis.md`](bds-qcombds-analysis.md), the ceiling in
[`static-blockers.md`](static-blockers.md), and the status appendix in
[`status-gaps.md`](status-gaps.md).

## 1. Milestone summary

| Item | State |
|------|-------|
| PD module stack in FV (`PmicGlinkDxe`, `UsbPwrCtrlDxe`, `QcomChargerDxeLA`, `ChargerExDxe`, `PILDxe`, `QcomChargerApp`) | **wired** (commits `e777d70` + earlier) |
| `QcomChargerCfg.cfg` + `uefiplat.cfg` + `uefipil.cfg` FREEFORM embeds | **present** (`RAW.inc` lines 258-266; stock-identical bytes) |
| `QcomChargerApp` in `FVMAIN.Fv` | **present** (UTF-16 UI + GUID `EEE9C2B1-16CA-4F34-87EA-2E6D1E160CC4`) |
| `PILDxe` in `FVMAIN.Fv` | **present** (UTF-16 UI + GUID `1D317734-4083-47C6-83EA-E3A42F2A6BFF`) |
| `DefaultChargerApp` auto-launch under Mu `BdsDxe` | **NOT wired** (no precedent; see §3) |
| BDS used | **`BdsDxe`** — `QcomBds` rejected/absent (0/85 Silicium) |
| Invented launch hook | **none** |
| `Status.md` USB PD row | **❌ unchanged** |
| Rebuild this pass | **none** (docs-only) |

`QcomChargerApp` is a `UEFI_APPLICATION` (`QcomChargerApp.inf`
`MODULE_TYPE = UEFI_APPLICATION`), so DXE dispatch does not run it. FV presence
is **not** execution; the stock pre-HLOS launch lives only in the prebuilt
`QcomBds.efi`.

## 2. Honesty P0 (why this pass exists)

The FULLCHAIN review (`/workspace/marble/dsh-tasks/REVIEW-uefi-marble-FULLCHAIN.md`
§1) flagged the gap: embedding `QcomChargerApp` **without** a launch path means
the pre-HLOS charger UI will **not** run automatically under Mu's `BdsDxe`, yet
the FV now contains the app. Left unqualified, "app in FV" invites the overclaim
"pre-HLOS charge UI works". This milestone keeps the claim at the static fact:
**app present in FV; it is not auto-launched.**

## 3. Launch-hook precedent search (result: none ≥90%)

Search target: a *proven* Silicium `ReadyToBoot` / `PlatformBootManager`
precedent that launches an application from a `uefiplat.cfg` string
(`DefaultChargerApp`). Result: **none**.

| Searched (2026-10-19, static) | Result |
|-------------------------------|--------|
| `DefaultChargerApp` in **buildable source** (`Silicon/`, `Common/`, `Platforms/**` `*.c/.h/.inf/.dsc/.inc/.fdf`) | **0** hits. |
| String consumer | Only the stock **prebuilt** `Binaries/marble/QcomPkg/Drivers/QcomBds/QcomBds.efi` (`strings -a`: `DefaultChargerApp`, `EnableChargerPdSupport`, `Failed to launch default charger app, status: %r`). |
| Stock config carriers | **68** `Binaries/*/RawFiles/uefiplat.cfg` carry `DefaultChargerApp` as stock config. |
| `QcomBds` buildable source | **0** — only `Binaries/*/QcomBds.{efi,inf,depex}` prebuilts (`DXE_DRIVER`, `PE32`, `[Depex] TRUE`). |
| Platforms enabling `QcomBds` | **0 / 85** `Platforms/**/Include/DXE.inc`. |
| Platforms enabling `QcomChargerApp` | **1 / 85** — marble only (`DXE.inc:80`); no port launches it. |
| Effective marble `PlatformBootManagerLib` (`SiliciumPkg/Library/BootManagerLib/BootManager.c`, `SiliciumPkg.dsc.inc:238` → `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf`) | **0** charger refs; **0** app `LoadImage`/`StartImage`; hooks are `BeforeConsole`/`AfterConsole`/`PriorityBoot` (Boot Manager menu)/`UnableToBoot`; `:237` calls `UpdateAcpiTables()`. |
| Effective marble `DeviceBootManagerLib` (`QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c`, `QcomPkg.dsc.inc:36`) | **0** charger refs; `AfterConsole` only signals `gUsbControllerInitGuid`/`gSdCardInitGuid`; `OnDemandConInConnect` `gUsbControllerInitGuid`; `BdsEntry` `ProtectRfsSharedArea()`. |
| `ReadyToBoot` handlers across `Silicon/` + `Common/` | **6** files register one; **0** mention the charger and **0** call `LoadImage`/`StartImage` (errata patch, advanced logger, var policy, display engine, Nvidia support, WHEA/BERT). |

**Gate:** 0/85 launch precedent + 0 buildable string consumers + prebuilt-only
`QcomBds` ⇒ **no ≥90% Silicium-proven hook**. Per the track gate, a launch hook
is **not invented**.

## 4. Decision

1. **Keep `BdsDxe`** — do **not** swap to or add `QcomBds` (0/85 Silicium;
   prebuilt-only; would risk the `UpdateAcpiTables()` / DT boot path).
2. **Do not invent** a `ReadyToBoot`/`PlatformBootManager` app-launch hook —
   no ≥90% precedent exists.
3. **Land honesty docs only.** `QcomChargerApp` remains manually launchable via
   the Boot Manager; automatic pre-HLOS launch stays a documented residual.
4. **Never flip `Status.md` USB PD ❌→✅** without on-device PD evidence.

## 5. Residuals (on-device; all still open)

1. `\image\adsp` must exist on the device partition for `PILDxe` (`uefipil.cfg`
   `[FULL_ADSP]`/`[CORE_ADSP]`).
2. pmic-glink must come up and ADSP ChargerFW must start
   (`PMIC_RTR_ADSP_APPS`, ChargerPD logging).
3. A runtime PD contract from `UsbPwrCtrl`/`PmicSchg`/Type-C — mainline DT has
   no `usb-c-connector`.
4. Optional, and only if a future proven hook is found: pre-HLOS auto-launch.

What would justify a Status ✅: an on-device log showing `\image\adsp` loaded,
glink/ChargerFW up, and a negotiated PD contract. Nothing static reaches that.

## 6. Static artifact record

- `Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv`: `strings -el` contains
  `PILDxe` and `QcomChargerApp`; `FVMAIN.Fv.txt` maps
  `1D317734-4083-47C6-83EA-E3A42F2A6BFF` @ `0x0044A0D0` and
  `EEE9C2B1-16CA-4F34-87EA-2E6D1E160CC4` @ `0x00372430`.
- `Mu-marble.img` = **1,728,512 B**, SHA256
  `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`
  (unchanged by this docs pass; no rebuild).
- Raw configs: `Binaries/marble/RawFiles/{uefiplat.cfg,uefipil.cfg,QcomChargerCfg.cfg}`.
- Indices: `Platforms/Xiaomi/marblePkg/Include/{DXE.inc,RAW.inc,APRIORI.inc}`.

## 7. Commit / push discipline

Firmware wiring that clears a ≥90% row is committed; this pass has **no**
firmware delta, so it commits **docs only**. Git runs under
`flock /workspace/marble/uefi/dsh/locks/git.lock` and pushes to
`fork/marble` only — never `origin`, never force.
