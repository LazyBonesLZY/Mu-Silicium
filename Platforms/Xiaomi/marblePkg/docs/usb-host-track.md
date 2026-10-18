# USB Host track — residuals only (marble UEFI)

Date: 2026-10-19 Asia/Shanghai. Branch `marble`. **ALL STATIC. No on-device
validation. No `Status.md` flip.** USB Host scope only.

Source disposition: parent
`/workspace/marble/uefi/notes/stock-re/REVIEW-uefi-marble-FULLCHAIN.md` §2 —
**ACCEPT wiring; HOLD Status.**

## 1. FULLCHAIN §2 disposition

The parent full-chain review accepted the existing Host wiring and blocked the
Status flip:

- `UsbConfigDxe.inf` selects `UsbConfigDxe.patched.efi`; real byte patch.
- XHCI / UsbBus APRIORI+DXE order present (`DXE.inc:86–91`).
- ACPI enabled (`6f7d432`) so `UsbConfigUpdateACPIEntry` / `UpdateDsdtTable` have
  an SDT; DSDT carries `URS0`/`USB0`/`UFN0`.
- Stock nested FV ships no UsbConfig/XHCI UI; Host stack is Device-Binaries.
- eUSB2 `nxp,ptn3222` is FDT-only → **no ≥90% ACPI paste**; do **not** flip FDT
  `dr_mode`.

Verdict unchanged this pass: wiring accepted, Status held at ❌.

## 2. Static bug audit (≥90% bar, USB Host only)

The track asked for three specific bug classes. All were searched and **none was
found**; no firmware delta cleared ≥90%.

### 2.1 Wrong INF PE32 — CLEAR

| Module INF | `PE32` target | vs pong |
|------------|---------------|---------|
| `UsbConfigDxe` | `UsbConfigDxe.patched.efi` | identical |
| `UsbMsdDxe` | `UsbMsdDxe.patched.efi` | identical |
| `UsbInitDxe` | `UsbInitDxe.efi` | identical |
| `XhciDxe` | `XhciDxe.efi` | identical |
| `XhciPciEmulationDxe` | `XhciPciEmulationDxe.efi` | identical |
| `UsbfnDwc3Dxe` | `UsbfnDwc3Dxe.efi` | identical |
| `UsbPwrCtrlDxe` | `UsbPwrCtrlDxe.efi` | identical |
| `UsbDeviceDxe` | `UsbDeviceDxe.efi` | identical |

`diff` of each marble vs pong INF shows only CRLF/LF line-ending noise; content
identical. Every `PE32|…`/`DXE_DEPEX|…` reference in every marble `APRIORI.inc` +
`DXE.inc` INF resolves to an existing file (no dangling reference).

Host-path patch re-verified at **file offset `0x5348`** (`cmp -l` 1-based
`21321/21322/21324`), exactly 3 differing bytes:

```
stock   : c8 01 00 34   CBZ X8, +56
patched : 0e 00 00 14   B   +56
```

- `UsbConfigDxe.efi` (stock)         sha256 `2c90173448c379e87da5b551701c3d9bb2ff51acdedd94db13479eb29233c3e6`
- `UsbConfigDxe.patched.efi`         sha256 `6b4ea2b59346fae043814289dbb9cbf505130da54ea9ec9781415e57f9e6556c`

### 2.2 APRIORI order vs pong — CLEAR

Normalized APRIORI sequence diff (basename only) shows the USB/charger block in
the **same relative order** as pong:

`PmicGlink → UsbPwrCtrl → QcomCharger → ChargerEx → Usbfn → XhciPciEmulation →
Xhci → UsbBus → UsbKb → UsbMassStorage → UsbMsd → UsbDevice → UsbConfig →
UsbInit` (with `PILDxe` earlier, before charger; PD path precedes UsbConfig —
correct for Type-C role / Vbus gating).

Only non-USB entries differ: marble has `ProjectInfoDxe`; pong has `LimitsDxe`,
`NT_DeviceInfoDxe`, `BootloaderLoggingDxe`. No USB-relevant divergence to fix.
`DXE.inc` USB order likewise matches pong (`QcomChargerApp` is the only extra
marble entry, and it is the PD app, not Host).

### 2.3 Missing module — CLEAR

Module-basename set comparison (`DXE.inc`): **no USB host module present in pong
is absent from marble.** Pong-only entries are all out of Host scope
(`BootloaderLoggingDxe`, `DisplayReEnablerDxe`, `NT_DeviceInfoDxe`); the only
marble-only entry is `QcomChargerApp.inf` (USB PD, landed `e777d70`). The full
Host set — `UsbfnDwc3Dxe`, `XhciPciEmulationDxe`, `XhciDxe`, `UsbBusDxe`,
`UsbKbDxe`, `UsbMassStorageDxe`, `UsbMsdDxe`, `UsbDeviceDxe`, `UsbConfigDxe`,
`UsbInitDxe` — is present in both `APRIORI.inc` and `DXE.inc`.

### 2.4 ACPI USB0/UFN0 + built FV — CLEAR

- `Silicium-ACPI/Platforms/Xiaomi/marble/Decompiled/DSDT.dsl`:
  `Device (URS0)` L1634, `Device (USB0)` L1648, `Device (UFN0)` L1814.
- `marble.dsc:90` `marble/AcpiTables.inf`; `marble.fdf:96–98` `AcpiTableDxe`,
  `AcpiPlatformDxe`, `ACPITABLE marble/AcpiTables.inf` — still enabled.
- `strings` of `UsbConfigDxe.patched.efi` contains `USB0`, `QUFN`,
  `UsbConfigUpdateACPIEntry: Failed to Locate SDT protocol`,
  `[UsbConfig]UpdateDsdtTable: Error opening the handle for DSDT tables`.
- Built FV used the **patched** binary: `…SEC2.1.pe32.txt` records
  `GenSec … UsbConfigDxe.patched.efi`; the artifact is the PE32 section with the
  4-byte `EFI_COMMON_SECTION_HEADER` `04 a0 01 10` (`0x1a004` size, type `0x10`)
  then `MZ`; stripping that header yields a byte-identical copy of
  `UsbConfigDxe.patched.efi`, and the patched `0e 00 00 14` is present at file
  offset `0x534C` (= section data `0x5348`).

No wrong PE32, no APRIORI divergence, no missing module.

## 3. Result — no firmware churn

Because no ≥90% static bug exists, this pass changes **no DXE/ACPI/DT/binary**
and does **not rebuild**. `Mu-marble.img` is unchanged:

- `Mu-marble.img` = **1,728,512 B**, SHA256
  `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`
- Docs only: this file.

## 4. Residual list (on-device only — no Status ✅)

1. **Host enumeration / XHCI transfers** — cannot be proven statically; no
   runtime log or device list.
2. **Type-C DFP role + Vbus gating** — `UsbConfig`/Type-C runtime; needs the
   PD/ADSP path (`usb-pd-re.md`) plus the connector state machine.
3. **eUSB2 PHY bring-up** — `UsbConfig` drives eUSB clocks/PHY via the binary
   (`gcc_eusb3_0_clkref_en`); the `nxp,ptn3222` node is FDT-only and has no
   pong-DSDT counterpart. **No PTN3222 AML is invented.**
4. **FDT `dr_mode = "peripheral"`** — correct for the Linux gadget/netboot story;
   Host role is UEFI `UsbConfig`, not DT. **Do not flip.**
5. **FV ~99% full** (952 B free) — any future host module needs a size plan
   (`host-windows-re.md` §4 / Appendix A).
6. **Windows side** — out of this track; tracked in `host-windows-re.md` §3 /
   `status-gaps.md`.

## 5. Explicit non-actions

- No invented PTN3222 AML / no fake ACPI paste.
- No FDT `dr_mode` flip to host.
- No new/borrowed Host module (pong parity already complete).
- No `QcomBds` swap (Host/PD tracks keep `BdsDxe`).
- **No `Status.md` ❌→✅.**

## 6. Citations

- Parent: `/workspace/marble/uefi/notes/stock-re/REVIEW-uefi-marble-FULLCHAIN.md`
  §2 (ACCEPT wiring; HOLD Status).
- [`host-windows-re.md`](host-windows-re.md) §§1–2, 5, Appendix A — stock FV /
  U-Boot facts + quality gate.
- [`static-blockers.md`](static-blockers.md) — USB Host bounded blocker.
- [`status-gaps.md`](status-gaps.md) §2 — Host wiring record.
- `Platforms/Xiaomi/marblePkg/Include/{APRIORI,DXE}.inc`;
  `Platforms/Nothing/pongPkg/Include/{APRIORI,DXE}.inc`.
- `Binaries/marble/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.{inf,efi,patched.efi}`.
- `Build/marblePkg/RELEASE_CLANGPDB/FV/Ffs/CD823A4D-7DEC-4531-AE5D-4134FA4127B8UsbConfigDxe/`.
