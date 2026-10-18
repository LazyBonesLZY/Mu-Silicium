# marble Status gaps — ACPI/DT dual boot, USB Host, USB PD, Linux Boot

Date: 2026-10-19 (Asia/Shanghai)
Scope: close the four `❌` rows in the repo `Status.md` entry for Xiaomi Poco F5
(`marble`): **USB Host Mode**, **USB Power Delivery**, **Windows Boot**, **Linux Boot**.

> **Verification statement.** Every change below is a *firmware source/build* change.
> None of it has been validated on a physical marble (Poco F5). Do not read this file
> as a claim of on-device success; it records what was implemented and the residual
> unknowns. The repo-level `Status.md` is intentionally **not** flipped to ✅.

> **Static ceiling reached for Status ✅.** The four ❌ rows below (USB Host, USB PD,
> Windows Boot, Linux Boot) cannot be raised to evidence-backed ✅ by any further
> static reverse-engineering. USB PD was reopened on the stock-RE-first policy and
> the actionable wiring (`PILDxe` + stock `QcomChargerApp`) is now embedded, but the
> row still needs on-device PD evidence. See
> [`static-blockers.md`](static-blockers.md) for the per-row hard blockers, citations,
> and goal disposition, and [`usb-pd-re.md`](usb-pd-re.md) for the PD evidence.
> No on-device validation is available or claimed.
>
> **Host/Windows stock-RE pass (docs-only).** The stock FV carve,
> `Binaries`/strings/DEPEX review, pong/venus/b4q DXE/APRIORI parity, and U-Boot
> `sm8475-xiaomi-marble` board facts are exhausted for further static firmware
> deltas ≥90%. See [`host-windows-re.md`](host-windows-re.md) and its
> quality-gate appendix. USB Host and Windows Boot remain on-device residuals;
> neither row is flipped to ✅ by this pass.
>
> **PD launch-hook pass (docs-only).** The Silicium BDS/DXE tree has **no
> ≥90% precedent** for auto-launching `DefaultChargerApp` (0 buildable
> consumers, prebuilt-only `QcomBds`, 0 app-launch hooks, 0/6 `ReadyToBoot`
> handlers). Per the track gate no hook is invented: `BdsDxe` stays, no
> `QcomBds`, and USB PD remains ❌. Milestone: [`pd-track.md`](pd-track.md).

Evidence base:

- `Platforms/Xiaomi/marblePkg/docs/re-stock-uefi.md` — director stock-RE notes
  (`Binaries/marble`, stock `uefiplat.cfg` / `QcomChargerCfg.cfg` / `BDS_Menu.cfg`).
- `Silicium-ACPI/Platforms/Nothing/pong/` — closest Palima sibling port
  (pong = SM8475, marble = SM7475-AB = `SOC_TYPE = 2`); ACPI + DT both enabled.
- `Silicon/Qualcomm/PalimaPkg/PalimaPkg.dsc.inc` — declares
  `AcpiTableUpdateLib|PalimaPkg/Library/AcpiTableUpdateLib/AcpiTableUpdateLib.inf`.
- `Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/BootManager.c:237` —
  `PlatformBootManagerBdsEntry()` calls `UpdateAcpiTables()` before
  `DeviceBootManagerBdsEntry()`.
- `Silicon/Qualcomm/QcomPkg/Include/Library/ConfigurationMapLib.h` —
  `EFI_CONFIGURATION_ENTRY_DESCRIPTOR.Value` is `UINT64` (numeric only).
- `Binaries/marble/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi` — local
  byte-level verification (`cmp -l`, `od`, `strings`).
- `Platforms/Xiaomi/marblePkg/docs/host-windows-re.md` — stock USB Host /
  Windows ACPI RE + U-Boot `sm8475-xiaomi-marble` facts, FVMAIN/image
  quality-gate appendix (106 GUIDs, 0 duplicates, 952 B FV headroom).

## Feature matrix

| Status.md row | Before | After this change | Mechanism / evidence | On-device |
|:--------------|:------:|:-----------------:|:---------------------|:---------:|
| USB Host Mode | ❌ | implemented, unverified | patched `UsbConfigDxe.patched.efi` kept (CBZ→B @ `0x5348`); XHCI/UsbBus APRIORI+DXE order is byte-for-byte identical to pong; ACPI SDT now present for `UsbConfigUpdateACPIEntry`/`UpdateDsdtTable`; stock FV has no UsbConfig/XHCI UI, U-Boot DWC3/eUSB mapping documented in [`host-windows-re.md`](host-windows-re.md) §§1–2 | ❌ not tested |
| USB Power Delivery | ❌ | wired (PIL + stock charger app), unverified | `QcomChargerCfg.cfg` + `uefipil.cfg` embedded; `PILDxe` enabled (`DXE.inc:98`) and stock `QcomChargerApp` embedded (`DXE.inc:80`); `PmicGlinkDxe`/`UsbPwrCtrlDxe`/`QcomChargerDxeLA`/`ChargerExDxe` in APRIORI+DXE; PD itself is ChargerPD over `pmic-glink` (ADSP); see `docs/usb-pd-re.md` | ❌ not tested |
| Windows Boot | ❌ | enabled, unverified | ACPI stack enabled in `marble.dsc`/`marble.fdf` (`AcpiTableDxe`, `AcpiPlatformDxe`, `ACPITABLE marble/AcpiTables.inf`) alongside `DtPlatformDxe` + FdtBlob; DSDT carries `URS0`/`USB0`/`UFN0`; stock ACPI carve has 0 DSDT/SSDT/XSDT/RSDT/FACP/APIC tables, and pong parity yields no further table delta (`host-windows-re.md` §3) | ❌ not tested |
| Linux Boot | ❌ | PlatCfg/BDS embedded, unverified | `DtPlatformDxe` + pinned `FdtBlob` kept; stock `uefiplat.cfg` (`DDE58710-…`) + `BDS_Menu.cfg` (`A91D838E-…`) RAW now embedded in `RAW.inc` with GUID/UI/bytes identical to stock (`docs/stock-fw-re.md` Findings A/E); EFI-stub + DT + Boot Manager path; `BdsDxe` kept by design — no `QcomBds` swap or addition (`docs/bds-qcombds-analysis.md`) | ❌ not tested |
| USB Device Mode | ✅ | unchanged | `UsbfnDwc3Dxe` + `UsbDeviceDxe`/`UsbConfigDxe`/`UsbInitDxe` unchanged | n/a |
| Mass Storage | ✅ | unchanged | `UsbMsdDxe` + `UsbMassStorageDxe` unchanged | n/a |

## 1. Windows Boot + USB Host ACPI dependency (implemented)

**What changed**

- New `Silicium-ACPI/Platforms/Xiaomi/marble/AcpiTables.inf` (adapted from pong),
  plus `DSDT.aml` and `Decompiled/DSDT.dsl` copied from
  `Silicium-ACPI/Platforms/Nothing/pong/`.
  - `ASL|DSDT.aml` is local to the package.
  - `ASL|Common/SSDT.aml` resolves through the `Silicium-ACPI` package path.
  - `ASL|Palima/{APIC,DBG2,FACP,GTDT,PPTT}.aml` resolve through the
    `Silicium-ACPI/Silicon/Qualcomm` package path — marble is Palima family, so the
    shared Palima tables are the correct match.
- `Platforms/Xiaomi/marblePkg/marble.dsc`: uncommented
  `marble/AcpiTables.inf` in `[Components]`.
- `Platforms/Xiaomi/marblePkg/marble.fdf`: enabled
  `AcpiTableDxe`, `AcpiPlatformDxe` and
  `INF RuleOverride = ACPITABLE marble/AcpiTables.inf`, **keeping**
  `DtPlatformDxe` and the FdtBlob FREEFORM (`25462CDA-221F-47DF-AC1D-259CFAA4E326`)
  for the dual ACPI + DT boot path, exactly like pong.
- `DeviceBuild.py` already lists `Silicium-ACPI/Platforms/Xiaomi` in
  `PackagesPath` (line 40), so no build-path change was needed.

**Why**

`UsbConfigDxe.patched.efi` contains the ACPI hooks and fails closed without a SDT:

```
UsbConfigUpdateACPIEntry: Failed to Locate SDT protocol
[UsbConfig]UpdateDsdtTable: Error opening the handle for DSDT tables
[UsbConfig] ACPI table pointer == NULL
```

With no ACPI tables there is no DSDT for `UsbConfigUpdateACPIEntry`/`UpdateDsdtTable`
to patch, so the host/Windows ACPI path is dead. `BootManager.c:237` then calls
`UpdateAcpiTables()` (backed by `AcpiTableUpdateLib`, already declared in
`PalimaPkg.dsc.inc`) which only does work when a DSDT is present — it returns early on
`EFI_NOT_FOUND`.

The copied pong DSDT is preferred over the tiny shared
`Palima/DSDT_Minimal.aml` precisely because it declares the USB ACPI nodes the patched
driver expects (`Silicium-ACPI/Platforms/Xiaomi/marble/Decompiled/DSDT.dsl`):

- line 1634 `Device (URS0)`, `_HID "QCOM0497"`
- line 1648 `Device (USB0)`
- line 1814 `Device (UFN0)`

**Residual risk**

- The DSDT OEM table ID is still `"SM8475 "` (pong/SM8475) while
  `PcdAcpiDefaultOemRevision` is `0x7475` for `SOC_TYPE = 2`. This is the
  documented "closest Palima DSDT" compromise; a marble-native DSDT from a stock
  XBL/UEFI dump would be better, but the OTA extract has no XBL/UEFI partitions
  (`re-stock-uefi.md` line 3).
- `EnableACPIFallback` stays `0x0`, matching pong/venus; it is consumed by a prebuilt
  binary through `ConfigurationMapLib`.
- Windows boot additionally depends on storage/USB class drivers and the OS itself;
  ACPI enablement is necessary but not sufficient, and this is unverified.

**Static ceiling for Windows Boot (docs-only, this pass).** The stock
`uefi.img`/nested-FV scan finds **0** valid DSDT/SSDT/XSDT/RSDT/FACP/APIC
tables, so there is no marble-native AML to lift. The pong/venus/b4q parity and
U-Boot `sm8475-xiaomi-marble` facts add no ACPI/DT delta ≥90% for Host or
Windows. See [`host-windows-re.md`](host-windows-re.md) §§2–3 and its
quality-gate appendix. The residuals are on-device (WoA winload/drivers/
secure-boot policy); **no Status ✅**.

## 2. USB Host (UEFI) (kept, verified against pong)

- `Binaries/marble/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf` already selects
  `PE32|UsbConfigDxe.patched.efi|*` — unchanged.
- The patch was re-verified locally: `cmp -l` reports exactly three differing bytes,
  decimal offsets `21321/21322/21324` = file `0x5348/0x5349/0x534B`:
  - stock `c8 01 00 34` = `CBZ X8, +56`
  - patched `0e 00 00 14` = `B +56` (unconditional take of the former `X8 == 0` path)
  This matches `re-stock-uefi.md` lines 7-12.
- The host-capable order is present and **identical to pong** in both
  `Include/APRIORI.inc` and `Include/DXE.inc`:
  `PmicGlinkDxe → UsbPwrCtrlDxe → QcomChargerDxeLA → ChargerExDxe → UsbfnDwc3Dxe →
  XhciPciEmulationDxe → XhciDxe → UsbBusDxe → UsbKbDxe → UsbMassStorageDxe →
  UsbMsdDxe → UsbDeviceDxe → UsbConfigDxe → UsbInitDxe`.
  No divergence to fix.
- Note: mainline DT sets `usb_1` `dr_mode = "peripheral"`, which affects the Linux
  host role only; it does not change the UEFI XHCI/UsbBus path.

**Static ceiling for USB Host (docs-only, this pass).** The stock nested FV ships
no `UsbConfig`/XHCI module UI; the Host stack is Device-Binaries. U-Boot facts
(`usb@a600000` DWC3, eUSB2 `nxp,ptn3222`, SimpleFB, memory windows) map to the
existing MemoryMap and do **not** justify an FDT `dr_mode` flip or a PTN3222
ACPI paste. See [`host-windows-re.md`](host-windows-re.md) §§1–2 and its
quality-gate appendix. Stock RE + U-Boot cross-check is exhausted: no further
static firmware delta clears ≥90%; enumeration/Type-C/Vbus remain on-device;
**no Status ✅**. The residual list and the targeted ≥90% static-bug audit
(wrong INF PE32 / APRIORI order vs pong / missing module — all clear) are in
[`usb-host-track.md`](usb-host-track.md).

## 3. USB Power Delivery (PIL + stock charger app embedded, unverified)

- `Include/RAW.inc` lines 258-266 embed both configs:
  - `FREEFORM = 45FE4B7C-150C-45DA-A021-4BEB2048EC6F` / UI `QcomChargerCfg.cfg`.
    The same GUID is used by pong and venus, so it is the Silicium-standard
    `QcomChargerCfg` GUID.
  - `FREEFORM = 21E9BDD9-6C3F-4F10-84A5-BBEC322741F1` / UI `uefipil.cfg`.
  - **Correction to `re-stock-uefi.md` line 17:** it attributes `21E9BDD9-…` to
    `QcomChargerCfg.cfg`. In marble (and pong/venus) `21E9BDD9-6C3F-4F10-84A5-
    BBEC322741F1` is `uefipil.cfg`; `QcomChargerCfg.cfg` is `45FE4B7C-…`.
- DXE has the charger stack: `PmicGlinkDxe`, `UsbPwrCtrlDxe`,
  `QcomChargerDxeLA`, `ChargerExDxe` (and `PmicDxeLa` in APRIORI).
- **PILDxe enabled** — `Include/DXE.inc:98` now includes
  `Binaries/marble/QcomPkg/Drivers/PILDxe/PILDxe.inf` (was `#INF`);
  `Include/APRIORI.inc:66` already listed it. `uefipil.cfg` `[FULL_ADSP]` and
  `[CORE_ADSP]` load `ImagePath = \image\adsp`, so PILDxe is the loader the
  ADSP ChargerFW path depends on. PILDxe is enabled in **56**
  `Platforms/**/Include/DXE.inc` ports (65 mention it; 9 leave it `#INF`),
  including pong (`Platforms/Nothing/pongPkg/Include/DXE.inc:102`).
- **Stock `QcomChargerApp` embedded** — `Include/DXE.inc:80` adds
  `Binaries/marble/QcomPkg/Application/QcomChargerApp/QcomChargerApp.inf`,
  immediately after `QcomChargerDxeLA`. The stock nested DXE FV ships the app
  (`/workspace/marble/uefi/notes/stock-re/carved/stock-uefi-modules.txt:36`);
  the stock carve
  (`/workspace/marble/uefi/notes/stock-re/pd/nested-carved/eee9c2b1-16ca-4f34-87ea-2e6d1e160cc4_APPLICATION/QcomChargerApp.efi`)
  is SHA256 `ff45707bfbf7745dfe82bd74182c3346709370466256cac8802d2a05a447efbd`,
  identical to `Binaries/marble`. Stock `uefiplat.cfg:129` also names it:
  `DefaultChargerApp = "QcomChargerApp"`. The earlier “0/85 Silicium ports”
  reject is **withdrawn** per the stock-RE-first policy: the stock FV is the
  authority here, and the FDF has no guessed entry — `DXE.inc` is included
  inside `[FV.FvMain]` by `marble.fdf:85`. `BdsDxe` is kept; no `QcomBds`
  swap/addition.
- PD proper is ChargerPD over `pmic-glink` (ADSP side: `ChargerPDLogging*`,
  `ChargerpdQBGDumpEnable`). There is no UEFI-side "PD enable" knob to add, and no
  fake config key was invented.
- Full static evidence, module inventory, DEPEX and FV verification:
  [`usb-pd-re.md`](usb-pd-re.md). Rebuild scan: `FVMAIN.Fv` contains UTF-16 UIs
  `PILDxe` and `QcomChargerApp`; FV GUIDs `1D317734-…` and `EEE9C2B1-…` are
  present. `Mu-marble.img` = 1,728,512 bytes, SHA256
  `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`.

**Residual risk:** a PD contract still needs (1) `\image\adsp` on the device
partition for PILDxe to load, (2) pmic-glink link-up / ADSP ChargerFW startup,
(3) a BDS path that auto-launches `DefaultChargerApp` (`BdsDxe` does not
string-match it; only stock QcomBds does), and (4) the Type-C/connector stack.
The firmware is now wired stock-faithfully, but none of this proves or provides
the ADSP PD state machine; it remains ❌ until validated on device.

**Launch-hook precedent search (this pass, docs-only).** For item (3), a static
search of the Silicium BDS/DXE tree found **no ≥90% precedent** for a
`ReadyToBoot`/`PlatformBootManager` auto-launch of `DefaultChargerApp`:
`DefaultChargerApp` has **0** buildable-source consumers; `QcomBds` exists only
as prebuilt `Binaries/*/QcomBds.efi` and is enabled by **0/85** `DXE.inc`; the
effective `PlatformBootManagerLib`
(`SiliciumPkg/Library/BootManagerLib/BootManager.c`) and `DeviceBootManagerLib`
(`QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c`) contain **0**
charger references and **0** application `LoadImage`/`StartImage`; **0/6**
`ReadyToBoot` handlers touch the charger. Per the track gate **no hook is
invented** — `BdsDxe` stays, no `QcomBds`, no `Status.md` flip. Evidence:
[`usb-pd-re.md`](usb-pd-re.md) §6.1 and milestone [`pd-track.md`](pd-track.md).

## 4. Linux Boot (stock PlatCfg/BDS embedded; DT path kept)

- `marble.fdf` keeps `DtPlatformDxe` and the pinned FdtBlob
  (`marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb`, pinned via `FdtBlob/Source.txt`).
- `Include/RAW.inc` now embeds the two stock configuration files verbatim
  (`docs/stock-fw-re.md` Findings A/E):
  - `FREEFORM = DDE58710-41CD-4306-DBFB-3FA90BB1D2DD` / UI `uefiplat.cfg` → RAW
    `Binaries/marble/RawFiles/uefiplat.cfg` (sha256 `5116faca…`, `cmp`-identical to
    stock carve `notes/stock-re/carved/stock-uefiplat.cfg`).
  - `FREEFORM = A91D838E-A5FA-4138-825D-455E2303079E` / UI `BDS_Menu.cfg` → RAW
    `Binaries/marble/RawFiles/BDS_Menu.cfg` (sha256 `1786bfcb…`, `cmp`-identical to
    stock carve `notes/stock-re/carved/stock-BDS_Menu.cfg`).
- This carries the stock string `DefaultBDSBootApp = "LinuxLoader"` inside
  `uefiplat.cfg` into the firmware image exactly as stock does, so the
  `ConfigurationMapLib` limitation (`EFI_CONFIGURATION_ENTRY_DESCRIPTOR.Value` is
  `UINT64`, `ConfigurationMapLib.h`) is bypassed rather than worked around — no
  string map was invented.
- Structural note: stock places `uefiplat.cfg` at the top-level `uefi.img` FV and
  `BDS_Menu.cfg` in the nested DXE FV; Mu's `RAW.inc` is included in `FvMain`
  (`marble.fdf`), so both are embedded one FV level higher while keeping the stock
  GUID/UI/RAW bytes.
- **BDS decision (kept by design):** `marble` keeps `BdsDxe` and does **not** switch to
  or add `QcomBds` (`docs/bds-qcombds-analysis.md`). Classification across Silicium is
  85 `BdsDxe` / 0 `QcomBds`; `SiliciumPkg.dsc.inc` binds
  `PlatformBootManagerLib` (`SiliciumPkg/Library/BootManagerLib/BootManagerLib.inf`)
  to `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf`. The stock `uefiplat.cfg` +
  `BDS_Menu.cfg` are embedded via `RAW.inc` while the Mu BDS remains `BdsDxe` — this
  is the pong/Nothing Silicium pattern, not a QcomBds port.
- Therefore Linux boot remains the Silicium EFI-stub + DT path: `DtPlatformDxe`
  publishes the DT and the Boot Manager (`BootManagerLib` / Mu patch) launches the
  installed boot entry. This is the pong pattern and is what commit `2e5a9f3` set up.
- Dual ACPI + DT note (from `re-stock-uefi.md` line 36): if ACPI wins the handoff on
  Linux, the kernel may need `acpi=off` (or `acpi=force`-style policy) to consume the
  DT instead. To be confirmed on device.

## Build and commits

- Rebuilt with `python3 build_uefi.py -d marble`
  (`HOME=$PWD/.home`, venv `/workspace/marble/uefi/.venv`): **Success**,
  `Mu-marble.img` regenerated.
- The build produced `Build/.../FV/Ffs/7E374E25-…AcpiTables/` with the ACPI table
  storage file; `SEC2.2` payload was verified byte-identical to the new
  `Silicium-ACPI/Platforms/Xiaomi/marble/DSDT.aml`.
- The ACPI/Linux pass above was local-only. The `Mu_Basecore` dirty submodule and
  `.home` are excluded from commits. The ACPI files live in the `Silicium-ACPI`
  submodule, so they are committed there and the outer repo records the updated
  submodule pointer alongside `marble.dsc`/`marble.fdf`/docs.
- USB PD pass (`e777d70`): same build command after enabling `PILDxe` and
  embedding `QcomChargerApp` → **Success**. `FVMAIN.Fv` is 6,627,328 B
  (952 B free); `Mu-marble.img` is **1,728,512 B**, SHA256
  `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`.
  FVMAIN UTF-16 UI scan contains both `PILDxe` and `QcomChargerApp`.
  Committed on local branch `marble` and pushed to `fork/marble` only
  (never `origin`; never `fork/main`). `Mu_Basecore` remains uncommitted.
- Host/Windows docs pass (this commit): **no rebuild**, no DXE/ACPI/DT or
  `Status.md` change. `Mu-marble.img` remains 1,728,512 B / SHA256
  `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`.
  Docs only: [`host-windows-re.md`](host-windows-re.md) plus pointers in this
  file and [`static-blockers.md`](static-blockers.md); pushed to `fork/marble`
  only.

## Unverified / follow-up

1. On-device: USB host (XHCI enumeration) and Windows boot with the new DSDT.
   Stock RE + U-Boot cross-check is exhausted; the remaining evidence is runtime
   ([`host-windows-re.md`](host-windows-re.md) §5).
2. On-device: PD negotiation through `pmic-glink`/ADSP with PILDxe + stock
   `QcomChargerApp` embedded; whether the app auto-launch matters under
   `BdsDxe` (see `usb-pd-re.md` §6).
3. On-device: Linux boot with ACPI+DT both present (may need `acpi=off`).
4. Replace the SM8475 pong DSDT with a marble-native one if a stock XBL/UEFI dump
   ever becomes available.

## Evidence confidence appendix (director gate, ≥90% rule)

| Claim | Confidence | Evidence paths | Commit allowed? |
|:------|:----------:|:---------------|:---------------:|
| Mu already ships host-capable UsbConfig patch | **≥95%** | `Binaries/marble/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf` (`PE32\|UsbConfigDxe.patched.efi`); `cmp -l` stock vs patched → 3 bytes @ `0x5348` (`CBZ X8,+56` → `B +56`); same pattern as `Binaries/pong/.../UsbConfigDxe.patched.efi` | yes (no code change) |
| UsbConfig ACPI hooks need a loaded DSDT/SDT | **≥95%** | strings in `.../UsbConfigDxe.patched.efi`: `UpdateDsdtTable`, `gAcpiSdt->FindPath`, `Failed to Locate SDT protocol`; `Silicon/.../BootManager.c` calls `UpdateAcpiTables()` | yes — enable AcpiTableDxe/AcpiPlatformDxe |
| DSDT must expose USB0 for FindPath | **≥90%** | same EFI contains ASCII `USB0` and `QUFN`; pong/marble `DSDT.dsl` has `Device (URS0)` / `Device (USB0)` / `Device (UFN0)` at lines 1634/1648/1814 (`Silicium-ACPI/Platforms/Nothing/pong/Decompiled/DSDT.dsl`) | yes — carry that DSDT |
| Pong DSDT is electrically/OEM-correct for SM7475 marble | **~70%** | DSDT OEM Table ID bytes = `SM8475` (`python` header parse of `Silicium-ACPI/Platforms/Xiaomi/marble/DSDT.aml`); marble `SOC_TYPE=2` → PCD OEM revision `0x7475`; no stock XBL/UEFI in OTA extract | **do not** claim Status ✅; keep as closest-Palima stand-in |
| UEFI USB Host “works on device” | **<50%** | firmware stack present; no `fastboot boot` log | Status stays ❌/unverified |
| USB PD fully works | **<50%** | `QcomChargerCfg.cfg` + `uefipil.cfg` + PmicGlink/UsbPwrCtrl present; PILDxe + stock `QcomChargerApp` now embedded (`DXE.inc:98`/`:80`); PD is ADSP ChargerPD; mainline DT has no usb-c-connector; no on-device PD contract | Status stays ❌ |
| Linux Boot via DT path is correctly wired in FV | **≥90%** | `marble.fdf` `DtPlatformDxe` + FREEFORM FdtBlob; `FdtBlob/Source.txt` commit `c9f87aac…`; prior commit `2e5a9f3` | keep; Status unverified on device |
| Stock `uefiplat.cfg` + `BDS_Menu.cfg` embedded with stock GUID/UI/RAW | **≥95%** | `docs/stock-fw-re.md` Findings A/E; carves `/workspace/marble/uefi/notes/stock-re/carved/stock-uefiplat.cfg` (sha256 `5116faca…`) and `/workspace/marble/uefi/notes/stock-re/carved/stock-BDS_Menu.cfg` (sha256 `1786bfcb…`), both `cmp`-identical to `Binaries/marble/RawFiles/`; `Include/RAW.inc` GUIDs `DDE58710-…`/`A91D838E-…`; LE GUID byte scan hits `uefi.img`@`0x49000` / `nested.fv`@`0x3AE628` | yes — `RAW.inc` |
| Linux Boot / PlatCfg statically matches stock FV embedding | **≥90%** | `docs/stock-fw-re.md` Findings A/E + carves above; `RAW.inc` GUID/UI/RAW identical to stock; residual is placement one FV level higher (`FvMain`) and no on-device boot | keep; Status stays ❌ until on-device |
| `DefaultBDSBootApp=LinuxLoader` reaches firmware like stock | **≥90%** | stock string lives in `Binaries/marble/RawFiles/uefiplat.cfg`; now embedded verbatim via `RAW.inc` GUID `DDE58710-…` (carve identical), so no `ConfigurationMapLib` string map is needed; `ConfigurationMapLib.h` `UINT64 Value` still rules out a *numeric* encoding | yes — stock cfg embed |
| Stock FV + pong/venus/b4q + U-Boot cross-check yields no further ≥90% Host/Windows firmware delta | **≥90% (ceiling)** | [`host-windows-re.md`](host-windows-re.md) §§1–3; stock nested FV lacks UsbConfig/XHCI UIs (`stock-uefi-modules.txt`); stock ACPI carve has 0 DSDT/SSDT/XSDT/RSDT/FACP/APIC; U-Boot `usb@a600000`/SimpleFB/memory facts already match MemoryMap | docs only — no code change |
| Stock Android `uefi.img` has no WoA ACPI tables to lift | **≥95%** | scan of `extracted/fw-uefi/*` + carved nested FV: 0 valid ACPI tables; [`host-windows-re.md`](host-windows-re.md) §3 | docs only |
| Windows Boot succeeds with current ACPI | **<50%** | ACPI stack and DSDT present; WoA winload/drivers/secure-boot policy and storage enumeration unverified | Status stays ❌/unverified |
| Replace `BdsDxe` with `QcomBds` | **≤40% / reject** | `0` Silicium `DXE.inc` use `QcomBds`; **85** use `BdsDxe` (`Platforms/**/Include/DXE.inc`); `Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc` binds `PlatformBootManagerLib\|SiliciumPkg/Library/BootManagerLib/BootManagerLib.inf` to `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf`; stock nested FV has `QcomBds` UI (`notes/stock-re/carved/nested.fv`, `stock-uefi-modules.txt`) but the Mu path is Silicium `BdsDxe` (`docs/bds-qcombds-analysis.md`) | no — keep `BdsDxe`; no swap/add |
| Embed stock `QcomChargerApp` + enable `PILDxe` in FV | **≥95%** | `DXE.inc:80` app, `DXE.inc:98` PILDxe; `FVMAIN.Fv` UTF-16 UI + GUID scan contains both after rebuild; stock app carve SHA256 `ff45707b…` = `Binaries/marble`; stock `stock-uefi-modules.txt:36` + `stock-uefiplat.cfg:129` name it; PILDxe enabled in **56** ports incl. pong (`pongPkg/Include/DXE.inc:102`); full evidence `docs/usb-pd-re.md` | yes — done in `e777d70` |
| `QcomChargerApp` auto-launch under Mu `BdsDxe` | **~0% / residual** | `BdsDxe` kept (85/85 Silicium ports); no `DefaultChargerApp` string match in `BdsDxe`; stock `QcomBds` only (prebuilt `.efi`, 0/85 `DXE.inc`); app is in FV and can be launched from Boot Manager | no — document residual (`usb-pd-re.md` §6/§6.1, `pd-track.md`) |
| No ≥90% Silicium `ReadyToBoot`/`BootManager` `DefaultChargerApp` launch precedent | **≥95% (none exists)** | buildable-source `DefaultChargerApp` consumers = 0 (`Silicon/`,`Common/`,`Platforms/**` `*.c/.h/.inf/.dsc/.inc/.fdf`); `QcomBds` source = 0 (only `Binaries/*/QcomBds.efi`); `0/85` `DXE.inc` enable `QcomBds`; effective `PlatformBootManagerLib` = `SiliciumPkg/Library/BootManagerLib/BootManager.c` and `DeviceBootManagerLib` = `QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c` contain 0 charger refs / 0 app `LoadImage`/`StartImage`; 0/6 `ReadyToBoot` handlers touch the charger; `QcomChargerApp.inf` is `UEFI_APPLICATION` (not DXE-dispatched) | docs only — **no hook invented**, `BdsDxe` kept, no `QcomBds` (`usb-pd-re.md` §6.1, `pd-track.md`) |

**Commit policy:** commit firmware wiring that clears a ≥90% row. Never flip repo `Status.md` ❌→✅ without on-device evidence. Residual <90% claims stay in this appendix as risks. When no code delta clears ≥90%, land docs and the quality-gate record only (as in the Host/Windows pass).
