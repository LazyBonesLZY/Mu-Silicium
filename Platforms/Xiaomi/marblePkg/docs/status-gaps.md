# marble Status gaps — ACPI/DT dual boot, USB Host, USB PD, Linux Boot

Date: 2026-10-19 (Asia/Shanghai)
Scope: close the four `❌` rows in the repo `Status.md` entry for Xiaomi Poco F5
(`marble`): **USB Host Mode**, **USB Power Delivery**, **Windows Boot**, **Linux Boot**.

> **Verification statement.** Every change below is a *firmware source/build* change.
> None of it has been validated on a physical marble (Poco F5). Do not read this file
> as a claim of on-device success; it records what was implemented and the residual
> unknowns. The repo-level `Status.md` is intentionally **not** flipped to ✅.

> **Static ceiling reached.** The four ❌ rows below (USB Host, USB PD, Windows Boot,
> Linux Boot) cannot be raised to evidence-backed ✅ by any further static
> reverse-engineering. **goal blocked: static ceiling.** See
> [`static-blockers.md`](static-blockers.md) for the per-row hard blockers, citations,
> and goal disposition. No on-device validation is available or claimed.

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

## Feature matrix

| Status.md row | Before | After this change | Mechanism / evidence | On-device |
|:--------------|:------:|:-----------------:|:---------------------|:---------:|
| USB Host Mode | ❌ | implemented, unverified | patched `UsbConfigDxe.patched.efi` kept (CBZ→B @ `0x5348`); XHCI/UsbBus APRIORI+DXE order is byte-for-byte identical to pong; ACPI SDT now present for `UsbConfigUpdateACPIEntry`/`UpdateDsdtTable` | ❌ not tested |
| USB Power Delivery | ❌ | documented, unverified | `QcomChargerCfg.cfg` already embedded (GUID `45FE4B7C-…`); `PmicGlinkDxe`/`UsbPwrCtrlDxe`/`QcomChargerDxeLA`/`ChargerExDxe` already in APRIORI+DXE; PD itself is ChargerPD over `pmic-glink` (ADSP) | ❌ not tested |
| Windows Boot | ❌ | enabled, unverified | ACPI stack enabled in `marble.dsc`/`marble.fdf` (`AcpiTableDxe`, `AcpiPlatformDxe`, `ACPITABLE marble/AcpiTables.inf`) alongside `DtPlatformDxe` + FdtBlob; DSDT carries `URS0`/`USB0`/`UFN0` | ❌ not tested |
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

## 3. USB Power Delivery (firmware already wired, unverified)

- `Include/RAW.inc` embeds `Binaries/marble/RawFiles/QcomChargerCfg.cfg` as
  `FREEFORM = 45FE4B7C-150C-45DA-A021-4BEB2048EC6F`. The same GUID is used by pong
  and venus, so it is the Silicium-standard `QcomChargerCfg` GUID.
  - **Correction to `re-stock-uefi.md` line 17:** it attributes `21E9BDD9-…` to
    `QcomChargerCfg.cfg`. In marble (and pong/venus) `21E9BDD9-6C3F-4F10-84A5-
    BBEC322741F1` is `uefipil.cfg`; `QcomChargerCfg.cfg` is `45FE4B7C-…`.
- DXE already has the charger stack: `PmicGlinkDxe`, `UsbPwrCtrlDxe`,
  `QcomChargerDxeLA`, `ChargerExDxe` (and `PmicDxeLa` in APRIORI).
- `QcomChargerApp.efi` exists under
  `Binaries/marble/QcomPkg/Application/QcomChargerApp/` but **no** `.fdf`/`.inc`
  references it, so it is not embedded in the image; the
  `DefaultChargerApp = "QcomChargerApp"` string in stock `uefiplat.cfg` is likewise
  not carried (see §4).
- **≥90% precedent check for adding it:** `QcomChargerApp` appears in **0/85**
  `Platforms/**/Include/DXE.inc` and in **no** `.fdf` across every Silicium port
  (`grep QcomChargerApp Platforms/` matches only these docs). The stock nested DXE FV
  VolInfo *does* list it (`notes/stock-re/carved/stock-uefi-modules.txt`), but there is
  no Silicium precedent for embedding/launching it. It therefore stays a **residual
  under USB PD** and is **not** added — no guessed `.fdf` entry.
- PD proper is ChargerPD over `pmic-glink` (ADSP side: `ChargerPDLogging*`,
  `ChargerpdQBGDumpEnable`). There is no UEFI-side "PD enable" knob to add, and no
  fake config key was invented.

**Residual risk:** full PD needs the Type-C/connector stack plus ADSP firmware
behaviour; it remains ❌ until validated on device. The UEFI charger/GLINK plumbing is
present but neither proves nor provides the ADSP PD state machine.

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
- Local commits only; nothing was pushed or uploaded. The `Mu_Basecore` dirty
  submodule and `.home` are excluded from commits. The ACPI files live in the
  `Silicium-ACPI` submodule, so they are committed there and the outer repo records
  the updated submodule pointer alongside `marble.dsc`/`marble.fdf`/docs.

## Unverified / follow-up

1. On-device: USB host (XHCI enumeration) and Windows boot with the new DSDT.
2. On-device: PD negotiation through `pmic-glink`/ADSP; whether embedding
   `QcomChargerApp` matters.
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
| USB PD fully works | **<50%** | `QcomChargerCfg.cfg` + PmicGlink/UsbPwrCtrl present; PD is ADSP ChargerPD; mainline DT has no usb-c-connector | document only; Status stays ❌ |
| Linux Boot via DT path is correctly wired in FV | **≥90%** | `marble.fdf` `DtPlatformDxe` + FREEFORM FdtBlob; `FdtBlob/Source.txt` commit `c9f87aac…`; prior commit `2e5a9f3` | keep; Status unverified on device |
| Stock `uefiplat.cfg` + `BDS_Menu.cfg` embedded with stock GUID/UI/RAW | **≥95%** | `docs/stock-fw-re.md` Findings A/E; carves `/workspace/marble/uefi/notes/stock-re/carved/stock-uefiplat.cfg` (sha256 `5116faca…`) and `/workspace/marble/uefi/notes/stock-re/carved/stock-BDS_Menu.cfg` (sha256 `1786bfcb…`), both `cmp`-identical to `Binaries/marble/RawFiles/`; `Include/RAW.inc` GUIDs `DDE58710-…`/`A91D838E-…`; LE GUID byte scan hits `uefi.img`@`0x49000` / `nested.fv`@`0x3AE628` | yes — `RAW.inc` |
| Linux Boot / PlatCfg statically matches stock FV embedding | **≥90%** | `docs/stock-fw-re.md` Findings A/E + carves above; `RAW.inc` GUID/UI/RAW identical to stock; residual is placement one FV level higher (`FvMain`) and no on-device boot | keep; Status stays ❌ until on-device |
| `DefaultBDSBootApp=LinuxLoader` reaches firmware like stock | **≥90%** | stock string lives in `Binaries/marble/RawFiles/uefiplat.cfg`; now embedded verbatim via `RAW.inc` GUID `DDE58710-…` (carve identical), so no `ConfigurationMapLib` string map is needed; `ConfigurationMapLib.h` `UINT64 Value` still rules out a *numeric* encoding | yes — stock cfg embed |

| Replace `BdsDxe` with `QcomBds` | **≤40% / reject** | `0` Silicium `DXE.inc` use `QcomBds`; **85** use `BdsDxe` (`Platforms/**/Include/DXE.inc`); `Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc` binds `PlatformBootManagerLib\|SiliciumPkg/Library/BootManagerLib/BootManagerLib.inf` to `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf`; stock nested FV has `QcomBds` UI (`notes/stock-re/carved/nested.fv`, `stock-uefi-modules.txt`) but the Mu path is Silicium `BdsDxe` (`docs/bds-qcombds-analysis.md`) | no — keep `BdsDxe`; no swap/add |
| Embed/launch `QcomChargerApp` in marble FDF/DXE | **~0% / reject (no precedent)** | `Binaries/marble/QcomPkg/Application/QcomChargerApp/QcomChargerApp.inf` exists; stock nested FV VolInfo lists `QcomChargerApp` (`notes/stock-re/carved/stock-uefi-modules.txt`); but `0/85` Silicium `DXE.inc` and no `.fdf` reference it (`grep QcomChargerApp Platforms/` → docs only) | no — document residual under USB PD |

**Commit policy:** commit firmware wiring that clears a ≥90% row. Never flip repo `Status.md` ❌→✅ without on-device evidence. Residual <90% claims stay in this appendix as risks.
