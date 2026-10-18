# Stock marble UEFI reverse-engineering notes (director)

Date: 2026-10-19 Asia/Shanghai. Sources: `Binaries/marble` (Device-Binaries), stock `uefiplat.cfg` / `QcomChargerCfg.cfg` / `BDS_Menu.cfg`. OTA extract under `/workspace/marble/extracted` has **no** XBL/UEFI partitions (only boot/vendor/odm) — UEFI evidence is Device-Binaries.

## UsbConfigDxe host patch (USB Host)

- `UsbConfigDxe.inf` already selects **`UsbConfigDxe.patched.efi`** (not the stock `.efi`).
- Byte diff stock→patched (same pattern as **pong**): **3 bytes @ file 0x5348**
  - stock insn `CBZ X8, +56` (`c8 01 00 34`)
  - patched `B +56` (`0e 00 00 14`) — **unconditional** take the former X8==0 path.
- Strings prove host stack exists: `InitHost`, `GetUsbHostConfig`, `UsbConfigToggleMode`, `UpdateDsdtTable` / ACPI SDT hooks.
- `USBHS1_Config=0x0` in stock cfg and ConfigurationMap (same on venus/kebab host-✅ devices) — **not** the host enable knob.
- **Decision:** Keep patched EFI. For Status Host: ensure Xhci + UsbBus path stays APRIORI/DXE ordered; enable **ACPI** so `UsbConfigUpdateACPIEntry` can patch DSDT (strings show it fails without SDT). Re-test narrative: Host ❌ in Status is likely ACPI/DSDT + Type-C policy, not missing patched binary.

## USB Power Delivery

- `QcomChargerCfg.cfg` already in `RAW.inc` (GUID `21E9BDD9-…`).
- PD path is **ChargerPD via PMIC GLINK** (`ChargerPDLogging*`, `ChargerpdQBGDumpEnable`) — ADSP-side, not a simple UEFI toggle.
- DXE already has `UsbPwrCtrlDxe`, `PmicGlinkDxe`, `QcomChargerDxeLA`, `ChargerExDxe`; `QcomChargerApp` exists only in `Binaries/marble/QcomPkg/Application/` and in stock nested-FV VolInfo (`notes/stock-re/carved/stock-uefi-modules.txt`) — no `.fdf`/`DXE.inc` reference in marble or any Silicium port (`docs/status-gaps.md` §3).
- Mainline DT: `pmic-glink` present; **no usb-c-connector**; `usb_1` `dr_mode=peripheral`.
- **Decision:** Document PD as best-effort (firmware already wired). Optional: ensure charger app / glink init order matches pong. Do not invent fake PD config keys.

## Linux Boot

- Stock `uefiplat.cfg`: `DefaultBDSBootApp = "LinuxLoader"` (string; **not** representable in UINT64 `ConfigurationMapLib`).
- Mu does **not** embed `uefiplat.cfg` in RAW (nor does pong) — numeric knobs come from ConfigurationMapLib; string BDS default is **not** currently carried unless another blob embeds it.
- Built FD contains string `USBHS1_Config` but need LinuxLoader app presence — Silicium uses EFI stub + DtPlatformDxe; marble already has **DtPlatformDxe + FdtBlob** (`2e5a9f3`).
- **Decision:** Keep DT path. Add FREEFORM RAW for `uefiplat.cfg` **and** `BDS_Menu.cfg` if a stock GUID is known from other Silicium ports; else document that Linux boot is via Boot Manager / EFI stub + DT (pong pattern) and update Status rationale. Search GUID for uefiplat across Binaries; if none, skip RAW and rely on DT + Boot-Manager Mu patch.

## Windows Boot

- marble.dsc/fdf: ACPI table INF **commented**; DtPlatform on.
- **pong** (Palima): ACPI + DtPlatform **both** enabled; `Silicium-ACPI/.../pong` DSDT + `AcpiTableUpdate` lib.
- No `Silicium-ACPI/Platforms/Xiaomi/marble` yet.
- UsbConfig strings update DSDT for USB — Windows/host benefit from ACPI.
- **Decision:** Clone pong ACPI → `Silicium-ACPI/Platforms/Xiaomi/marble`, retarget INF, uncomment ACPI in marble.dsc/fdf **keeping** DtPlatform (dual like pong). Document Linux may need `acpi=off` if ACPI wins. SOC_TYPE marble=2 (SM7475-AB); pong=0 (SM8475) — still closest Palima DSDT + update lib.

## Already done (do not redo)

- PIL memmap `0x1DC00000`, pinned DTB script, `Mu-marble.img` build, commits `2e5a9f3` / `201614d`.
