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

### USB Power Delivery — firmware wired; Status flip blocked
- **Wiring done (this pass):** `PILDxe` enabled (`Include/DXE.inc:98`;
  `APRIORI.inc:66` already listed it) and stock `QcomChargerApp` embedded
  (`Include/DXE.inc:80`). The app carve SHA256 is identical to `Binaries/marble`
  and the stock nested FV lists it (`stock-uefi-modules.txt:36`). `FVMAIN.Fv`
  now contains both UTF-16 UIs and both GUIDs after rebuild. `QcomChargerCfg.cfg`
  + `uefipil.cfg` RAW, UsbPwrCtrl (`UsbPwrCtrlLib_GetPDStatus`), PmicGlink and
  QcomChargerDxe were already present. Full evidence:
  [`usb-pd-re.md`](usb-pd-re.md). The stock-RE-first policy supersedes the
  earlier “0/85 Silicium ports ship QcomChargerApp” reject; no guessed FDF entry
  was needed because `DXE.inc` is inside `[FV.FvMain]`.
- **Residual blocker:** PD policy is ADSP ChargerPD over pmic-glink; it needs
  `\image\adsp` on the device partition for PILDxe, glink link-up / ADSP
  ChargerFW startup, and a runtime PD contract. Mainline DT has no
  `usb-c-connector` (pinned DTS comment). `BdsDxe` does not auto-launch
  `DefaultChargerApp` (stock QcomBds only); the app is in the FV but automatic
  pre-HLOS launch is not wired.
- **Cite:** `Platforms/Xiaomi/marblePkg/Include/DXE.inc`; `Include/RAW.inc`
  lines 258-266; `Binaries/marble/RawFiles/QcomChargerCfg.cfg` /
  `uefipil.cfg`; `Binaries/marble/QcomPkg/Application/QcomChargerApp/`;
  `Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv` +
  `FVMAIN.Fv.txt`; `/workspace/marble/uefi/notes/stock-re/carved/stock-uefi-modules.txt`;
  `docs/usb-pd-re.md`; `docs/bds-qcombds-analysis.md`.

### Windows Boot — ACPI family ≥90%; OS boot Status flip blocked
- **Wiring done:** ACPI+DT dual like pong; Palima TID `SM8475` consistent with Silicium Palima packages.
- **Blocker:** No marble-native DSDT in stock `uefi.img` (0 DSDT signatures). Full WoA boot needs unverifiable OS/storage stack statically.
- **Cite:** `docs/stock-fw-re.md` Finding B; `extracted/fw-uefi/uefi.img` nested FV scan.

### Linux Boot — static PlatCfg+DT+BdsDxe ≥90%; Status flip blocked
- **Wiring done:** DtPlatform+FdtBlob; stock-identical `uefiplat.cfg`/`BDS_Menu.cfg` FREEFORM; BdsDxe kept (`docs/bds-qcombds-analysis.md`).
- **Blocker:** Status ✅ would assert successful Linux boot — not statically knowable.
- **Cite:** `RAW.inc` GUIDs `DDE58710…` / `A91D838E…`; commit `b1e69db`.

## Goal disposition
The earlier static pass marked all four Status.md rows at the static ceiling.
USB PD was then reopened on the stock-RE-first policy: the remaining actionable
wiring (`PILDxe` + stock `QcomChargerApp`) is now implemented and FV-verified,
but a PD contract still requires on-device ADSP/glink evidence. The four
`Status.md` rows remain ❌; no further static pass can flip them. Artifact for
parent review: `/workspace/marble/uefi/Mu-Silicium/Mu-marble.img` (USB PD
rebuild, 1,728,512 B, SHA256
`f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`).
