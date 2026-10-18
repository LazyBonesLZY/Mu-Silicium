# Stock marble firmware RE (static, OTA partitions)

Date: 2026-10-19 Asia/Shanghai. Gate: ≥90% static confidence only (no on-device).

## Sources extracted
From `/workspace/marble/fw/marble-ota.zip` via payload-dumper-go → `/workspace/marble/extracted/fw-uefi/`:
`uefi.img` (2.7MiB), `imagefv.img`, `xbl.img`, `xbl_config.img`, `abl.img`, `uefisecapp.img`, `devcfg.img`, `xbl_ramdump.img`.

## Finding A — stock embeds `uefiplat.cfg` (≥95%)
- Evidence: `VolInfo` on `uefi.img` FV @ `0x1000` shows FREEFORM GUID **`DDE58710-41CD-4306-DBFB-3FA90BB1D2DD`**, UI string `uefiplat.cfg`, RAW size `0x1F76`.
- Carved file: `/workspace/marble/uefi/notes/stock-re/carved/stock-uefiplat.cfg`
- `cmp` vs `Binaries/marble/RawFiles/uefiplat.cfg` → **IDENTICAL** (sha256 prefix `5116faca4329b3b9`).
- Stock strings include `DefaultBDSBootApp = "LinuxLoader"` (inside that cfg).
- **Gap:** `Platforms/Xiaomi/marblePkg/Include/RAW.inc` does **not** embed this GUID/file (confirmed by rg). Silicium Mu therefore drops stock PlatCfg that Qcom Env/BDS reads.
- **Fix (≥95%):** add FREEFORM to `RAW.inc` (and ensure FDF includes RAW.inc path as today) with GUID `DDE58710-41CD-4306-DBFB-3FA90BB1D2DD`, UI `uefiplat.cfg`, RAW `Binaries/marble/RawFiles/uefiplat.cfg`. Optionally embed `BDS_Menu.cfg` only if stock FV lists it with a GUID (not required for this claim).

## Finding B — stock nested DXE FV has **no ACPI tables** (≥95%)
- Nested FV inside uefi.img is **gzip** (magic `1f8b08`), GUID-defined section `1d301fe9-be79-4353-91c2-d23bc959ae0c`, decompressed to `/workspace/marble/uefi/notes/stock-re/carved/nested-fv-gzip.bin` / `nested.fv`.
- Scan for `DSDT`/`SSDT`/`FACP`/`APIC` signatures → **0 hits**.
- VolInfo module list: no `AcpiTableDxe` / `AcpiPlatformDxe` UI strings.
- **Conclusion:** marble-native DSDT **does not exist in stock Android UEFI**. Pong-derived DSDT remains a WoA/Silicium construct; do not claim it is stock marble. Keep dual ACPI+DT as community port pattern; confidence for “matches stock ACPI” = N/A (absent).

## Finding C — USB/PD modules in stock DXE FV (static inventory)
Module UI list: `/workspace/marble/uefi/notes/stock-re/carved/stock-uefi-modules.txt` (from VolInfo).
USB/charger-related names present in stock (see that file for exact UI strings). Mu `DXE.inc` already carries UsbConfig (patched), UsbPwrCtrl, PmicGlink, Xhci, etc. from Device-Binaries — do not change without a module-level binary diff ≥90%.

## Finding D — xbl_config `USB0`
`xbl_config.img` contains `NAMEDNODE_USB0` / `_USB0` SID mapping blobs (offsets `0x15116`, `0x151c8`) — XBL resource config, not ACPI DSDT.

## Finding E — stock embeds `BDS_Menu.cfg` (≥95%)
- Evidence: the nested DXE FV (decompressed from `uefi.img`, see Finding B) lists FREEFORM GUID **`A91D838E-A5FA-4138-825D-455E2303079E`**, UI string `BDS_Menu.cfg`, at nested-FV offset `0x3AE628` (little-endian GUID byte scan).
- Carved file: `/workspace/marble/uefi/notes/stock-re/carved/stock-BDS_Menu.cfg`
- `cmp` vs `Binaries/marble/RawFiles/BDS_Menu.cfg` → **IDENTICAL** (sha256 `1786bfcb2616efed81ac761f7dc23c63ecd260f1235683b3a67e526ed13018c8`).
- **Gap:** `Platforms/Xiaomi/marblePkg/Include/RAW.inc` did **not** embed this GUID/file (confirmed by rg). Stock BDS menu (boot order / `DefaultBDSBootApp` context) is therefore dropped by Silicium Mu.
- **Fix (≥95%):** add FREEFORM to `RAW.inc` with GUID `A91D838E-A5FA-4138-825D-455E2303079E`, UI `BDS_Menu.cfg`, RAW `Binaries/marble/RawFiles/BDS_Menu.cfg`. Note: stock places it in the nested DXE FV; Mu's `RAW.inc` is included in `FvMain` (see `marble.fdf`), so the file is embedded one FV level higher while retaining the stock GUID/UI/bytes.

## Actions for coding agent
1. Patch `RAW.inc` to embed stock `uefiplat.cfg` with GUID above.
2. Update `docs/status-gaps.md` + this file citations; Linux Boot static confidence ↑ because PlatCfg+DefaultBDSBootApp now in FV like stock.
3. Rebuild `Mu-marble.img`; local commit; no push; no Status.md ✅; no upload.
4. Do **not** replace DSDT with “stock” (none). Optionally note Finding B in confidence appendix.
