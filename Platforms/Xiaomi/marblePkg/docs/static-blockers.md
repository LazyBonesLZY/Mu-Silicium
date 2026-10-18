# Static confidence ceiling — hard blockers (marble UEFI)

Date: 2026-10-19 Asia/Shanghai. **No on-device. No Status.md ✅. No upload.**

## Raised this pass

| Claim | New conf. | Evidence |
|-------|-----------|----------|
| Palima DSDT OEM TID `SM8475` is Silicium-correct for marble (SM7475-AB / `SOC_TYPE=2`) | **≥90%** | `Silicium-ACPI/Silicon/Qualcomm/Palima/DSDT_Minimal.aml` TID=`SM8475`; pong/marble/b4q platform DSDTs also `SM8475`; not an accidental pong-only label |
| UsbConfig ACPI hooks target `USB0`/`UFN0`/`QUFN` nodes present in carried DSDT | **≥90%** | strings in `Binaries/marble/.../UsbConfigDxe.patched.efi` (`USB0`,`QUFN`,`UpdateDsdtTable`); `Silicium-ACPI/.../marble/Decompiled` / pong `DSDT.dsl` Devices `URS0`,`USB0`,`UFN0` |
| Stock Android `uefi.img` DXE FV does **not** ship UsbConfig/Xhci UI modules | **≥90%** | `notes/stock-re/carved/stock-uefi-modules.txt` (56 UIs: QcomBds/QcomChargerApp/…); `strings` nested FV has PHY MMIO names but no `UsbConfigDxe` module UI — Silicium Host stack comes from **Device-Binaries**, not stock FV |

## Still below 90% for claiming Status gap “done” (hard blockers)

### USB Host Mode — firmware wiring ≥90%; Status flip blocked
- **Wiring done:** patched UsbConfig, XHCI/UsbBus, ACPI SDT for UpdateDsdtTable (commits `6f7d432`+).
- **Blocker:** Cannot statically prove host enumerates devices. Stock FV lacks UsbConfig module to A/B against. No runtime log allowed.
- **Cite:** `stock-uefi-modules.txt`; `UsbConfigDxe.patched.efi` strings; `docs/re-stock-uefi.md`.

### USB Power Delivery — blocked
- **Present:** `QcomChargerCfg.cfg` RAW, UsbPwrCtrl (`UsbPwrCtrlLib_GetPDStatus`), PmicGlink, QcomChargerDxe — firmware surfaces exist.
- **Blocker:** PD policy is ADSP ChargerPD over pmic-glink; mainline DT has no `usb-c-connector` (pinned DTS comment). `QcomChargerApp` in stock/Binaries but **0/85** Silicium ports ship it — cannot add without guessing.
- **Cite:** `Binaries/marble/RawFiles/QcomChargerCfg.cfg`; UsbPwrCtrl strings; `linux-marble` `sm8475-xiaomi-marble.dts` pmic-glink notes via `docs/mainline-crosscheck.md`; `docs/bds-qcombds-analysis.md` charger-app residual.

### Windows Boot — ACPI family ≥90%; OS boot Status flip blocked
- **Wiring done:** ACPI+DT dual like pong; Palima TID `SM8475` consistent with Silicium Palima packages.
- **Blocker:** No marble-native DSDT in stock `uefi.img` (0 DSDT signatures). Full WoA boot needs unverifiable OS/storage stack statically.
- **Cite:** `docs/stock-fw-re.md` Finding B; `extracted/fw-uefi/uefi.img` nested FV scan.

### Linux Boot — static PlatCfg+DT+BdsDxe ≥90%; Status flip blocked
- **Wiring done:** DtPlatform+FdtBlob; stock-identical `uefiplat.cfg`/`BDS_Menu.cfg` FREEFORM; BdsDxe kept (`docs/bds-qcombds-analysis.md`).
- **Blocker:** Status ✅ would assert successful Linux boot — not statically knowable.
- **Cite:** `RAW.inc` GUIDs `DDE58710…` / `A91D838E…`; commit `b1e69db`.

## Goal disposition
Further static passes will not raise the four Status.md rows to evidence-backed ✅. Mark goal **blocked** (`model-reported`) with this file as reason. Artifact for parent review: `/workspace/marble/uefi/Mu-Silicium/Mu-marble.img` (latest rebuild from `b1e69db` era; docs-only commits after).
