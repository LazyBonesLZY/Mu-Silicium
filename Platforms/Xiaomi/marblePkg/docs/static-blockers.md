# Static confidence ceiling — hard blockers (marble UEFI)

Date: 2026-10-19 Asia/Shanghai. **No on-device. No Status.md ✅. No upload.**

## Raised this pass

| Claim | New conf. | Evidence |
|-------|-----------|----------|
| Palima DSDT OEM TID `SM8475` is Silicium-correct for marble (SM7475-AB / `SOC_TYPE=2`) | **≥90%** | `Silicium-ACPI/Silicon/Qualcomm/Palima/DSDT_Minimal.aml` TID=`SM8475`; pong/marble/b4q platform DSDTs also `SM8475`; not an accidental pong-only label |
| UsbConfig ACPI hooks target `USB0`/`UFN0`/`QUFN` nodes present in carried DSDT | **≥90%** | strings in `Binaries/marble/.../UsbConfigDxe.patched.efi` (`USB0`,`QUFN`,`UpdateDsdtTable`); `Silicium-ACPI/.../marble/Decompiled` / pong `DSDT.dsl` Devices `URS0`,`USB0`,`UFN0` |
| Stock Android `uefi.img` DXE FV does **not** ship UsbConfig/Xhci UI modules | **≥90%** | `notes/stock-re/carved/stock-uefi-modules.txt` (56 UIs: QcomBds/QcomChargerApp/…); `strings` nested FV has PHY MMIO names but no `UsbConfigDxe` module UI — Silicium Host stack comes from **Device-Binaries**, not stock FV |
| U-Boot `sm8475-xiaomi-marble` DWC3/SimpleFB/memory facts already match Mu MemoryMap | **≥90%** | U-Boot DTS `usb@a600000` + `androidboot.usbcontroller=a600000.dwc3`; `framebuffer@b8000000` 1080×2400/stride 4320; Mu `MemoryMap` `"USB" 0x0A600000/0x200000`, `"Display Reserved" 0xB8000000/0x02B00000`, PCD 1080/2400/32; [`host-windows-re.md`](host-windows-re.md) §2 |
| Stock Android `uefi.img` has no WoA ACPI tables to lift | **≥95%** | scan of `extracted/fw-uefi/*` + carved nested FV: **0** valid DSDT/SSDT/XSDT/RSDT/FACP/APIC; no marble-native AML; [`host-windows-re.md`](host-windows-re.md) §3 |
| No further Host/Windows static firmware delta reaches ≥90% (stock RE + U-Boot exhausted) | **≥90% (ceiling)** | stock FV UsbConfig/XHCI absence; pong/venus/b4q DXE/APRIORI parity; U-Boot facts above; 0 stock ACPI tables; FV/image quality gate in [`host-windows-re.md`](host-windows-re.md) Appendix A |

## Still below 90% for claiming Status gap “done” (hard blockers)

### USB Host Mode — firmware wiring ≥90%; Status flip blocked
- **Wiring done:** patched UsbConfig, XHCI/UsbBus, ACPI SDT for UpdateDsdtTable (commits `6f7d432`+).
- **Stock RE + U-Boot exhausted (docs-only):** stock nested FV ships no
  `UsbConfig`/XHCI UI; DWC3 `0x0A600000` and SimpleFB `0xB8000000` already match
  `MemoryMap`; the eUSB2 `nxp,ptn3222` node has no pong-DSDT ACPI counterpart and
  no ≥90% paste; FDT `dr_mode=peripheral` must **not** be flipped for UEFI Host.
  No further static firmware delta clears ≥90% — see
  [`host-windows-re.md`](host-windows-re.md) §§1–2 and Appendix A.
- **Residual blocker:** Cannot statically prove host enumerates devices; Type-C
  DFP/Vbus/eUSB PHY bring-up is on-device. Stock FV lacks UsbConfig module to A/B
  against. No runtime log allowed. **No Status ✅.**
- **Cite:** `stock-uefi-modules.txt`; `UsbConfigDxe.patched.efi` strings;
  `docs/re-stock-uefi.md`; [`host-windows-re.md`](host-windows-re.md);
  [`usb-host-track.md`](usb-host-track.md) (residual list + ≥90% static-bug
  audit: INF PE32 / APRIORI vs pong / missing module — all clear).

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
- **Launch-hook precedent search (this pass, docs-only):** `0` buildable
  `DefaultChargerApp` consumers; `QcomBds` is prebuilt-only (`QcomBds.efi`) and
  `0/85` `DXE.inc` enable it; the effective `PlatformBootManagerLib`
  (`SiliciumPkg/Library/BootManagerLib/BootManager.c`, `SiliciumPkg.dsc.inc:238`)
  and `DeviceBootManagerLib`
  (`QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c`,
  `QcomPkg.dsc.inc:36`) contain **0** charger references and **0** application
  `LoadImage`/`StartImage`; `0/6` `ReadyToBoot` handlers across `Silicon/`+
  `Common/` touch the charger. No ≥90% hook exists → **none invented**;
  `BdsDxe` kept, no `QcomBds`. Milestone: [`pd-track.md`](pd-track.md).
- **Cite:** `Platforms/Xiaomi/marblePkg/Include/DXE.inc`; `Include/RAW.inc`
  lines 258-266; `Binaries/marble/RawFiles/QcomChargerCfg.cfg` /
  `uefipil.cfg`; `Binaries/marble/QcomPkg/Application/QcomChargerApp/`;
  `Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv` +
  `FVMAIN.Fv.txt`; `/workspace/marble/uefi/notes/stock-re/carved/stock-uefi-modules.txt`;
  `docs/usb-pd-re.md` §6.1; `docs/bds-qcombds-analysis.md`;
  `docs/pd-track.md`;
  `Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/BootManager.c`;
  `Silicon/Qualcomm/QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c`.

### Windows Boot — ACPI family ≥90%; OS boot Status flip blocked
- **Wiring done:** ACPI+DT dual like pong; Palima TID `SM8475` consistent with Silicium Palima packages.
- **Stock RE + U-Boot exhausted (docs-only):** stock `uefi.img`/nested-FV scan has
  **0** DSDT/SSDT/XSDT/RSDT/FACP/APIC tables, so there is no marble-native AML to
  add; pong/venus/b4q parity yields no further table delta ≥90%; U-Boot facts add
  no ACPI requirement beyond the existing `USB0`/`UFS0` nodes. No further static
  firmware delta clears ≥90% — see [`host-windows-re.md`](host-windows-re.md) §3
  and Appendix A.
- **Residual blocker:** WoA winload/drivers/secure-boot policy and storage/USB
  enumeration are on-device. ACPI enablement is necessary but not sufficient.
  **No Status ✅.**
- **Cite:** `docs/stock-fw-re.md` Finding B; `extracted/fw-uefi/uefi.img` nested FV
  scan; [`host-windows-re.md`](host-windows-re.md).

### Linux Boot — static PlatCfg+DT+BdsDxe ≥90%; Status flip blocked
- **Wiring done:** DtPlatform+FdtBlob; stock-identical `uefiplat.cfg`/`BDS_Menu.cfg` FREEFORM; BdsDxe kept (`docs/bds-qcombds-analysis.md`).
- **Chain verified (docs-only, this pass):** pinned DTB sha256 `a242627f…` is
  byte-identical to a fresh `scripts/build-marble-dtb.sh` build from
  `FdtBlob/Source.txt` (`c9f87aac…`) and is present (GUID `25462CDA-…`) in both
  `FVMAIN.Fv` and the LZMA-nested `FVMAIN` of the packaged
  `Mu-marble.img`/`SILICIUM_UEFI.fd`; `DtPlatformDxe` defaults to DT
  (`PcdDefaultDtPref=TRUE`, `EmbeddedPkg.dec:189`) and installs `gFdtTableGuid`
  (kernel `DEVICE_TREE_GUID`); the arm64 kernel prefers a real DT over ACPI by
  default (`arch/arm64/kernel/acpi.c:198-209`), so the dual ACPI+DT FDF does not
  break the DT handoff. FDT pin-to-kernel-HEAD delta is peripheral-only.
- **Residuals (all on-device or user-side):** actual boot to userspace; ESP
  `\EFI\BOOT\BOOTAA64.EFI` boot-option discovery through the `BdsDxe` Boot
  Manager; kernel cmdline (EFI LoadOptions overrides the DTB's hard-coded pmOS
  `bootargs`; `extlinux.conf` is not read); a `DtAcpiPref` variable set to ACPI
  would suppress the FDT table. Full detail:
  [`linux-boot-track.md`](linux-boot-track.md).
- **Blocker:** Status ✅ would assert successful Linux boot — not statically knowable.
- **Cite:** `RAW.inc` GUIDs `DDE58710…` / `A91D838E…`; commit `b1e69db`;
  `marble.fdf:104-108`; `DtPlatformDxe.c:148/209`; `MdePkg.dec:634`;
  [`linux-boot-track.md`](linux-boot-track.md).

## Goal disposition
The earlier static pass marked all four Status.md rows at the static ceiling.
USB PD was then reopened on the stock-RE-first policy: the remaining actionable
wiring (`PILDxe` + stock `QcomChargerApp`) is now implemented and FV-verified,
but a PD contract still requires on-device ADSP/glink evidence. The four
`Status.md` rows remain ❌; no further static pass can flip them.

The PD launch-hook pass searched the Silicium BDS/DXE tree for a
`DefaultChargerApp` auto-launch precedent and found **none ≥90%** (0/85,
prebuilt-only `QcomBds`, 0 buildable string consumers, 0 app-launch hooks).
Per the track gate it lands **docs only**: `BdsDxe` is kept, no `QcomBds`, and
no launch hook is invented. Milestone: [`pd-track.md`](pd-track.md).

The Host/Windows pass landed docs only: stock FV/`Binaries`/DEPEX, pong/venus/b4q
DXE parity, and U-Boot `sm8475-xiaomi-marble` facts are exhausted for further
≥90% firmware deltas ([`host-windows-re.md`](host-windows-re.md)). USB Host and
Windows Boot residuals are on-device; **no Status flip**. Artifact for parent
review: `/workspace/marble/uefi/Mu-Silicium/Mu-marble.img` (unchanged by the docs
pass, 1,728,512 B, SHA256
`f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`).
