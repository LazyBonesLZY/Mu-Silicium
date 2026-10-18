# USB Host + Windows Boot — stock RE + U-Boot cross-check (marble)

Date: 2026-10-19 Asia/Shanghai. **ALL STATIC.** No on-device validation. No `Status.md` ✅ from build or static analysis alone.

## Executive decision (leader)

After the stock FV carve, `Binaries`/strings/DEPEX review, Silicium sibling
(pong/venus/b4q) DXE/APRIORI parity, and U-Boot `sm8475-xiaomi-marble` board
facts: **no additional DXE/RAW/ACPI firmware delta reaches ≥90% static
confidence** beyond what is already in tree at `e777d70` (PD: `PILDxe` +
`QcomChargerApp`) and the earlier Host/Windows commits (`6f7d432` ACPI+DT,
patched `UsbConfig`, XHCI stack).

This pass **documents** the evidence and quality-gate results. Status rows stay
❌. There is no code change and no rebuild.

## 1. USB Host — stock + sibling RE

### Stock nested FV (`/workspace/marble/uefi/notes/stock-re/carved/nested.fv`)

- **No** `UsbConfigDxe` / `XhciDxe` / `UsbfnDwc3` / `UsbInit` module UIs
  (56 modules: `QcomBds`, `QcomChargerApp`, `PmicDxe`, `GlinkDxe`, …).
- The Host stack for Silicium comes from **Device-Binaries**, not the stock
  Android `uefi.img` DXE FV.
- Cite: `/workspace/marble/uefi/notes/stock-re/carved/stock-uefi-modules.txt`.

### Binaries marble (in Mu FV)

| Module | UI in FVMAIN | Notes |
|--------|--------------|-------|
| `UsbConfigDxe.patched.efi` | `UsbConfigDxe` | INF selects patched; patch pattern ≡ pong (3 differing bytes: `CBZ X8,+56` → `B +56` at file `~0x5348`; `cmp -l` 1-based offsets 21321/21322/21324) |
| `UsbInitDxe` | `UsbInitDxe` | DEPEX PUSH `gQcomUsbConfigProtocolGuid` |
| `XhciDxe` | `XhciDxe` | Present |
| `XhciPciEmulationDxe` | **`XhciPciEmulation`** (UI omits `Dxe`) | Present; see Appendix A probe note |
| `UsbfnDwc3Dxe` | `UsbfnDwc3Dxe` | Device/gadget path |
| `UsbBus`/`UsbKb`/`UsbMassStorage` | yes | MdeModulePkg |

### APRIORI / DXE order vs pong

Marble USB+charger APRIORI order matches pong: `PmicGlink → UsbPwrCtrl → QcomCharger → ChargerEx → Usbfn → XhciPciEmulation → Xhci → UsbBus* → UsbMsd/Device → UsbConfig → UsbInit`. The PD stack (including `PILDxe` earlier in APRIORI) precedes `UsbConfig` — correct for Type-C role / Vbus gating (`GetTypeCPortStatus`, `Data Role : DFP (HOST Mode)` strings in `UsbConfig`).

### `UsbConfig` host-path strings (static)

`Usb30InitHost`, `SynopsysInitHostConfig`, `GetUsbHostConfig`, `UsbEnableVbus`,
`gcc_eusb3_0_clkref_en`, `UpdateDsdtTable`; targets `USB0` / Type-C role
UFP↔DFP. Needs an ACPI SDT+DSDT (now present: DSDT/SSDT/APIC/FACP/GTDT/PPTT/DBG2
magics in FVMAIN).

### Sibling / Status signal

The marble `Status.md` row is ❌. Other devices do report USB Host ✅ in
`Status.md` (42 rows), but those are community reports without captured boot
evidence in this tree, and the sibling DXE/APRIORI parity already checked
(pong/venus/b4q) shows no host-enabling module delta to borrow. The stock FV has
no `UsbConfig`/XHCI module to A/B against, so it is not a known-good Host recipe
either.

## 2. U-Boot marble board facts → UEFI mapping (facts only)

Source: `/workspace/marble/src/u-boot-marble/dts/upstream/src/arm64/qcom/sm8475-xiaomi-marble.dts`
+ `board/qualcomm/xiaomi-marble.config`.

| Fact | U-Boot / DT | Mu-Silicium mapping | Conf. |
|------|-------------|---------------------|-------|
| DWC3 MMIO | `usb@a600000` / `androidboot.usbcontroller=a600000.dwc3` | MemoryMap `"USB" 0x0A600000/0x200000`; `uefiplat` same | ≥90% |
| eUSB2 repeater | `nxp,ptn3222` @ i2c5 `0x4f`, reset pm8350c gpio7 | Embedded FDT already has `redriver@4f` / `compatible = "nxp,ptn3222"` (pinned linux-marble DTB). **UEFI Host does not bind this node** — `UsbConfig` talks eUSB clocks/PHY via the binary (`gcc_eusb3_0_clkref_en`). No DSDT paste of PTN3222 (pong DSDT has no such device either). | ≥90% (fact); no ACPI patch ≥90% |
| `dr_mode` | `"peripheral"` (netboot/gadget choice in U-Boot/linux DT) | FDT mirrors peripheral. **Do not** flip FDT to host for UEFI Host — role switch is `UsbConfig`/Type-C at runtime, not DT `dr_mode`. | ≥90% leave as-is |
| SimpleFB | `framebuffer@b8000000` 1080×2400 stride 4320 a8r8g8b8 size 0x2b00000 | MemoryMap `"Display Reserved" 0xB8000000/0x02B00000`; PCD 1080/2400/32; `SimpleFbDxe` | ≥90% match |
| Memory banks | 12 GiB multi-bank reg list | `MemoryMapLib` reserved windows aligned to stock `uefiplat` + PIL `0x1DC00000`; high HYP `0x830000000` present | ≥90% for UEFI; full bank Conv is OS/ABL concern |
| USB gadget in U-Boot | `CONFIG_USB_GADGET*` / `usbacm` | Explains Device Mode ✅ path; not Host | — |

**No U-Boot C was pasted into EDK2.**

## 3. Windows Boot — stock ACPI + sibling

### Stock ACPI carve

Scan of `extracted/fw-uefi/*` + carved nested FV: **0** valid
DSDT/SSDT/XSDT/RSDT/FACP/APIC tables (acpi-like hits = 0). Stock Android UEFI
does not ship WoA ACPI blobs to lift.

### Marble ACPI (already enabled)

`Silicium-ACPI/Platforms/Xiaomi/marble/AcpiTables.inf` ≡ pong set: local DSDT
(`URS0`/`USB0`/`UFN0` + `UFS0`) + `Common/SSDT` + Palima
APIC/DBG2/FACP/GTDT/PPTT. OEM TID `SM8475` is consistent with
Palima/`SOC_TYPE=2` (SM7475-AB). FVMAIN contains
DSDT/SSDT/APIC/FACP/GTDT/PPTT/DBG2.

### Sibling Windows ✅

pong (Palima SM8475) claims Windows Boot ✅ in `Status.md` with the same ACPI INF
pattern marble already mirrors. No further table borrow without marble-native AML
(none in stock).

### UFS

DSDT `Device (UFS0)` is present — the storage ACPI path for WoA is structurally
present; winload/BCD are out of scope.

## 4. Quality gate (build ≠ done)

Raw output: **Appendix A** (verbatim `quality-gate.txt`). Captured against the
current `Mu-marble.img` / FVMAIN (post-`e777d70`, unchanged by this docs pass):

- FVMAIN: total `0x652000`, taken `0x651c48` → **952 B free (~99% full)** —
  headroom risk; do not add large modules without FD/FV budget review
  (`Resources/Configs/marble.toml` `uefi_fd` size `0x300000`).
- UI PRESENT: `PILDxe`, `QcomChargerApp`, `UsbConfigDxe`, `UsbInitDxe`,
  `XhciDxe`, `XhciPciEmulation`, `UsbfnDwc3Dxe`, `UsbPwrCtrlDxe`,
  `PmicGlinkDxe`, `QcomChargerDxeLA`, `ChargerExDxe`, `BdsDxe`, `DtPlatformDxe`,
  `AcpiTableDxe`, `SimpleFbDxe`, `uefiplat`/`QcomChargerCfg`/`BDS_Menu`/`uefipil`.
- ACPI + FDT magics present in FV.
- FFS unique GUIDs: 106, **0 duplicate FILE GUIDs**.
- Img: `1728512` B, SHA256
  `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`
  (unchanged this docs pass).
- DEPEX: `UsbPwrCtrl` TRUE; `UsbInit` depends on `UsbConfig` protocol;
  `UsbConfig` multi-protocol AND; `PILDxe` depends on a Pmic-related protocol —
  satisfied by modules present in FV/APRIORI.

## 5. Residuals (on-device only — no Status ✅)

1. **USB Host enumeration** — cannot prove device list / XHCI transfer
   statically; Type-C DFP + Vbus + eUSB PHY bring-up need runtime.
2. **Windows Boot** — ACPI tables present but WoA boot success (winload, drivers,
   secure-boot policy) is not statically knowable; no stock AML to further
   specialize the DSDT.
3. **FDT `dr_mode=peripheral`** — correct for the Linux gadget/netboot story;
   Host role is UEFI `UsbConfig`, not DT.
4. **FV ~99% full** — future modules need a size plan.

Stock RE + U-Boot cross-check is exhausted for further static firmware deltas:
the remaining evidence for USB Host and Windows Boot can only come from the
device. **No `Status.md` flip.**

## 6. Changes in this docs pass

Docs only: this file under `Platforms/Xiaomi/marblePkg/docs/host-windows-re.md`;
pointers in [`status-gaps.md`](status-gaps.md) and
[`static-blockers.md`](static-blockers.md). **No DXE/ACPI/DT binary edits** (none
cleared ≥90%). **No rebuild** (artifact unchanged). **No `Status.md` flips.**

## Appendix A — `quality-gate.txt` (verbatim)

Probe note: the literal UI scan below looks for `XhciPciEmulationDxe`. The FV UI
is `XhciPciEmulation` (no `Dxe` suffix), so the module is present under its
actual UI; the `ABSENT` line is a probe-name mismatch, not a missing module.

```text
FVMAIN size 6627328
FV len field 6627328
hdr len 72
EFI_FV_TOTAL_SIZE = 0x652000
EFI_FV_TAKEN_SIZE = 0x651c48
taken/total from build log style:
EFI_FV_TOTAL_SIZE = 0x652000
EFI_FV_TAKEN_SIZE = 0x651c48

UI scan:
  PILDxe: PRESENT@0x467108
  QcomChargerApp: PRESENT@0x38a450
  UsbConfigDxe: PRESENT@0x438024
  UsbInitDxe: PRESENT@0x440078
  XhciDxe: PRESENT@0x3f3848
  XhciPciEmulationDxe: ABSENT
  UsbfnDwc3Dxe: PRESENT@0x3d16d4
  UsbPwrCtrlDxe: PRESENT@0x3944a8
  PmicGlinkDxe: PRESENT@0x3533c0
  QcomChargerDxeLA: PRESENT@0x372408
  ChargerExDxe: PRESENT@0x347378
  BdsDxe: PRESENT@0x2d8ea0
  DtPlatformDxe: PRESENT@0x49badc
  AcpiTableDxe: PRESENT@0x495010
  SimpleFbDxe: PRESENT@0x3342a0
  uefiplat.cfg: PRESENT@0x486cfc
  QcomChargerCfg.cfg: PRESENT@0x368d3e
  BDS_Menu.cfg: PRESENT@0x4878b8
  uefipil.cfg: PRESENT@0x45ddd0

ACPI magics: {'DSDT': 4401115, 'SSDT': 4807860, 'APIC': 4813128, 'FACP': 4814932, 'GTDT': 4815212, 'PPTT': 4815372, 'DBG2': 4813876}
FDT d00dfeed 4832020
Mu-marble.img 1728512 f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6
FFS file count 106 unique GUIDs 106 dup GUIDs {}
Binaries/marble/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.depex 02690476b00c977a48a4b528db7b45cef102d0c7e5f439d2cb47aacd7f66ef76323802455c7a15b221c543ba7c822fee5fe599028e0897ebdfcfc649be4bd906a5b20e8603030308
Binaries/marble/QcomPkg/Drivers/UsbInitDxe/UsbInitDxe.depex 023fb022e750b2ce428ebd5bd51812d03708
Binaries/marble/QcomPkg/Drivers/PILDxe/PILDxe.depex 0242b937ae7f45914ca196d9669fd347a308
Binaries/marble/QcomPkg/Drivers/UsbPwrCtrlDxe/UsbPwrCtrlDxe.depex 0608
```
