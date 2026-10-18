# USB PD stock RE and Mu wiring — marble (SM7475)

Date: 2026-10-19 Asia/Shanghai. **ALL STATIC. No on-device. No Status.md ✅.**
Scope: the USB Power Delivery stack for Xiaomi Poco F5 (`marble`): stock
reverse-engineering evidence, the Mu modules that carry it, the two wiring gaps
closed in this pass (`PILDxe`, `QcomChargerApp`), and the residual that still
prevents a Status ✅.

Stock carves referenced below live **outside this repository**, in the
director's workspace: `/workspace/marble/uefi/notes/stock-re/`.

## 1. Module inventory

| Module | Stock nested FV | `Binaries/marble` | Mu `FVMAIN` before this pass | Role |
|--------|:---------------:|:-----------------:|:----------------------------:|------|
| `QcomChargerApp` | **YES** (UI line 36 of `stock-uefi-modules.txt`) | YES, SHA256 identical to stock carve | **ABSENT** | Pre-HLOS charge UI; locates `QcomChargerProtocol` |
| `QcomChargerDxeLA` | no (Device-Binaries only) | YES | PRESENT (UI `QcomChargerDxeLA`) | Loads ADSP ChargerFW via PmicGlink; reads `QcomChargerCfg` |
| `ChargerExDxe` | no | YES | PRESENT | Installs `ChargerExProtocol` |
| `UsbPwrCtrlDxe` | no | YES | PRESENT | `GetPDStatus`, `GetTypeCPortStatus`, Vbus/Vconn; needs PmicSchg + ADC |
| `PmicGlinkDxe` | no | YES | PRESENT | `PMIC_RTR_ADSP_APPS` / ChargerPD log channels |
| `GlinkDxe` | YES | YES | PRESENT (UI `GlinkDxe`) | Transport for pmic-glink |
| `PmicDxe` / `PmicDxeLa` | YES | YES | PRESENT | SCHG/FG/Type-C PMIC surfaces (`EFI_PmicSchg*`) |
| `PwrUtilsDxe` | YES | YES | PRESENT | Power utilities |
| `PILDxe` | no (not in the 56-UI list) | YES (`.efi` + `.depex`) | **ABSENT** (`DXE.inc` `#INF`) | Loads `uefipil.cfg` images including `FULL_ADSP` |
| `PILProxyDxe` | — | YES | PRESENT | PIL proxy |
| `QcomChargerCfg.cfg` | — (Binaries RAW) | YES | PRESENT (`FREEFORM 45FE4B7C-…`, `EnableChargerFW = 1`) | Charger/PD policy config |
| `uefipil.cfg` | — | YES | PRESENT (`FREEFORM 21E9BDD9-…`) | `FULL_ADSP` / `CORE_ADSP` `ImagePath = \image\adsp` |
| `uefiplat.cfg` | YES | YES | PRESENT | `DefaultChargerApp = "QcomChargerApp"` |

Evidence paths:

- Stock module list: `/workspace/marble/uefi/notes/stock-re/carved/stock-uefi-modules.txt`
  (line 36 `QcomChargerApp`), carved from
  `/workspace/marble/uefi/notes/stock-re/carved/nested.fv`.
- Stock app carve:
  `/workspace/marble/uefi/notes/stock-re/pd/nested-carved/eee9c2b1-16ca-4f34-87ea-2e6d1e160cc4_APPLICATION/QcomChargerApp.efi`,
  SHA256 `ff45707bfbf7745dfe82bd74182c3346709370466256cac8802d2a05a447efbd`
  — byte-identical to
  `Binaries/marble/QcomPkg/Application/QcomChargerApp/QcomChargerApp.efi`
  (`cmp` clean).
- Stock policy strings: `/workspace/marble/uefi/notes/stock-re/carved/stock-uefiplat.cfg`
  line 129 `DefaultChargerApp = "QcomChargerApp"`.
- Mu binaries: `Binaries/marble/QcomPkg/Application/QcomChargerApp/QcomChargerApp.inf`
  (`FILE_GUID EEE9C2B1-16CA-4F34-87EA-2E6D1E160CC4`, `UEFI_APPLICATION`,
  `PE32|QcomChargerApp.efi`), `Binaries/marble/QcomPkg/Drivers/PILDxe/PILDxe.inf`
  (`DXE_DRIVER`, `DXE_DEPEX|PILDxe.depex`, `[Depex] TRUE`).
- Mu configs: `Platforms/Xiaomi/marblePkg/Include/RAW.inc` lines 258-266 embed
  `uefipil.cfg` (`21E9BDD9-6C3F-4F10-84A5-BBEC322741F1`) and
  `QcomChargerCfg.cfg` (`45FE4B7C-150C-45DA-A021-4BEB2048EC6F`);
  `Binaries/marble/RawFiles/uefipil.cfg` contains `[FULL_ADSP] ImagePath = \image\adsp`,
  `[CORE_ADSP]` the same path; `Binaries/marble/RawFiles/QcomChargerCfg.cfg`
  line 61 `EnableChargerFW = 1`, lines 173-187 ChargerPD logging.

## 2. DEPEX

- `ChargerExDxe` / `PmicGlinkDxe` / `UsbPwrCtrlDxe` / `QcomChargerDxeLA`: `TRUE` `END`
- `GLinkDxe`: `PUSH 52858ad7-8b16-4137-9c64-dfe04d942e80` `END`
- `PmicDxeLa`: `PUSH ae37b942…` AND `PUSH fa5f306b…` `END`
- `QcomChargerApp`: no DEPEX — `MODULE_TYPE = UEFI_APPLICATION`
  (`QcomChargerApp.inf`). DXE dispatch does **not** run applications, so FV
  presence is not execution; a launch must come from BDS / the Boot Manager
  (see §6.1).
- `PILDxe`: `TRUE` (`PILDxe.inf` `[Depex] TRUE`, `PILDxe.depex` present)

## 3. PD / Type-C contract initiation (static)

1. **ADSP ChargerPD path (primary PD policy):**
   - `QcomChargerDxe` strings: `EnableChargerFW`, `ChargerLibTarget_LoadChargerFW`,
     `adsp`, `use PmicGlink`, `pmicGlinkProtocol Connect`, `ChargerPD Logging`,
     `pmic_glink_cpdlog_process_rx_data`.
   - Config: `QcomChargerCfg.cfg` `EnableChargerFW = 1`,
     `ChargerPDLoggingCategories`, `ChargerPDLoggingLevel`,
     `ChargerPDLoggingSize`, `ChargerpdQBGDumpEnable`, `GLinkDownAction`.
   - PIL: `uefipil.cfg` `[FULL_ADSP]` needs **PILDxe** in the FV to load
     `\image\adsp` from the device partition at runtime.
2. **PMIC / UsbPwrCtrl path (status surfaces):**
   - `UsbPwrCtrlLib_GetPDStatus`, `GetTypeCPortStatus`, Vbus detect/source;
     locates `PmicSchgProtocol`, `AdcProtocol`, `PmicVersionProtocol`.
   - `PmicDxe` provides SCHG charger-port APIs (`EFI_PmicSchgGetChargerPortType`).
3. **QcomChargerApp:** UI/monitor over `QcomChargerProtocol` (from
   `QcomChargerDxe`). Stock **QcomBds** honours `uefiplat.cfg`
   `DefaultChargerApp = "QcomChargerApp"`; Mu keeps **BdsDxe** (Silicium), which
   does **not** string-match `DefaultChargerApp`. Embedding the stock app is
   stock-faithful; auto-launch under `BdsDxe` remains a residual.

## 4. Mu wiring implemented in this pass

`Platforms/Xiaomi/marblePkg/Include/DXE.inc`:

```diff
   INF Binaries/marble/QcomPkg/Drivers/QcomChargerDxe/QcomChargerDxeLA.inf
+  INF Binaries/marble/QcomPkg/Application/QcomChargerApp/QcomChargerApp.inf
   INF Binaries/marble/QcomPkg/Drivers/UsbPwrCtrlDxe/UsbPwrCtrlDxe.inf
...
-  #INF Binaries/marble/QcomPkg/Drivers/PILDxe/PILDxe.inf
+  INF Binaries/marble/QcomPkg/Drivers/PILDxe/PILDxe.inf
```

- `DXE.inc` line 80 now embeds the stock `QcomChargerApp`; line 98 enables
  `PILDxe`.
- `Include/APRIORI.inc` lines 65-67 already listed `PILProxyDxe` → `PILDxe` →
  `SPSSDxe`; no APRIORI change is needed (same pattern as pong,
  `Platforms/Nothing/pongPkg/Include/APRIORI.inc:65` and
  `Platforms/Nothing/pongPkg/Include/DXE.inc:102`).
- `DXE.inc` is included inside `[FV.FvMain]` by `marble.fdf:85`, so both INFs are
  packed into `FVMAIN.Fv` without an FDF edit. `BdsDxe` is kept; `QcomBds` is
  **not** added or swapped in.
- PILDxe precedent: **56** `Platforms/**/Include/DXE.inc` files enable it
  (65 mention it; 9 leave it `#INF`), including pong; the marble binary already
  existed in `Binaries/marble` and was already listed in `APRIORI.inc`. Stock RE
  wins over the earlier “0 Silicium ports ship QcomChargerApp” objection: the
  stock nested DXE FV ships it and its bytes are identical to `Binaries/marble`.

## 5. Static verification (after rebuild)

- Rebuilt `Mu-marble.img` with the project build entry point
  (`HOME=$PWD/.home python3 build_uefi.py -d marble`).
- `FVMAIN.Fv` UTF-16 UI scan (`strings -el`) must contain both `PILDxe` and
  `QcomChargerApp`; see the table below for the recorded run.
- No on-device test was performed and no artifact was uploaded.

| Check | Result |
|-------|--------|
| Build | `HOME=$PWD/.home python3 build_uefi.py -d marble` → **Success** (exit 0) |
| `FVMAIN.Fv` UTF-16 UI `PILDxe` | **PRESENT** (`strings -el FVMAIN.Fv \| grep -x PILDxe`) |
| `FVMAIN.Fv` UTF-16 UI `QcomChargerApp` | **PRESENT** |
| FV GUID map (`FVMAIN.Fv.txt`) | `1D317734-4083-47C6-83EA-E3A42F2A6BFF` @ `0x0044A0D0`; `EEE9C2B1-16CA-4F34-87EA-2E6D1E160CC4` @ `0x00372430` |
| FFS output | `Ffs/1D317734-…PILDxe/` (PE32 118,788 B + DEPEX 22 B); `Ffs/EEE9C2B1-…QcomChargerApp/` (PE32 98,308 B) |
| Embedded payload identity | `cmp -i 4:0` on each generated `SEC*.pe32` against its `Binaries/marble` `.efi` is **identical** (only the 4-byte EFI section header differs); PILDxe DEPEX likewise identical |
| FVMAIN capacity | 6,627,328 B total / 6,626,376 B used / **952 B free (99 % full)** |
| `Mu-marble.img` | **1,728,512 bytes**, SHA256 `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6` |

The FVMAIN headroom is now only 952 bytes; the next module addition will
need an FV-size/compression review. This does not affect the current image.


## 6. Residual — why Status.md USB PD stays ❌

The firmware wiring is now stock-faithful, but a PD contract is still not
statically provable:

1. **ADSP image must exist on the device partition.** `uefipil.cfg`
   `[FULL_ADSP]` loads `\image\adsp`; PILDxe in the FV only provides the loader.
   The OTA extract has no XBL/UEFI partitions and no on-device partition dump was
   taken.
2. **pmic-glink must come up at runtime.** ChargerPD is an ADSP-side state
   machine over `PMIC_RTR_ADSP_APPS`; `PmicGlinkDxe`/`GlinkDxe` presence does not
   prove link-up or charger-firmware load.
3. **`BdsDxe` does not auto-launch `DefaultChargerApp`.** The stock
   `uefiplat.cfg` string is embedded, but Mu's `BdsDxe` does not implement the
   stock QcomBds string match. The app is in the FV and can be launched through
   the Boot Manager; automatic pre-HLOS launch is not wired. The Silicium
   launch-hook precedent search (§6.1) found no ≥90% template, so no hook was
   invented.
4. **Type-C policy is not proven.** Mainline DT has `pmic-glink` but no
   `usb-c-connector`; the UEFI-side `UsbPwrCtrl` status surfaces do not by
   themselves establish a PD contract.

Therefore `Status.md` is **not** flipped: “PILDxe + QcomChargerApp embedded” is
a static FV fact, not evidence of a successful PD negotiation.

### 6.1 Precedent search for a `DefaultChargerApp` launch hook — none ≥90%

Because the app is in `FVMAIN` but `BdsDxe` does not string-match
`DefaultChargerApp`, this pass searched the Silicium BDS/DXE tree for any
*proven* `ReadyToBoot` / `PlatformBootManager` precedent that launches an
application from a `uefiplat.cfg` string. There is none at the ≥90% bar.

| Searched (2026-10-19, static) | Result |
|-------------------------------|--------|
| `DefaultChargerApp` in **buildable source** (`Silicon/`, `Common/`, `Platforms/**` `*.c/.h/.inf/.dsc/.inc/.fdf`) | **0** hits. The string is consumed only by the stock **prebuilt** `Binaries/marble/QcomPkg/Drivers/QcomBds/QcomBds.efi` (`strings -a`: `DefaultChargerApp`, `EnableChargerPdSupport`, `Failed to launch default charger app, status: %r`). 68 `Binaries/*/RawFiles/uefiplat.cfg` carry it as stock config. |
| `QcomBds` buildable source | **0** — only `QcomBds.{efi,inf,depex}` prebuilts under `Binaries/*` (`MODULE_TYPE = DXE_DRIVER`, `PE32|QcomBds.efi`, `[Depex] TRUE`). No source port to copy a string-match from. |
| Platforms that enable `QcomBds` | **0 / 85** `Platforms/**/Include/DXE.inc`. |
| Platforms that enable `QcomChargerApp` | **1 / 85** — marble only (`DXE.inc:80`); no port launches it. |
| Effective marble `PlatformBootManagerLib` = `Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/BootManager.c` (bound by `SiliciumPkg.dsc.inc:238` to `MdeModulePkg/Universal/BdsDxe/BdsDxe.inf`) | **0** `charger` / `ChargerApp` / `DefaultChargerApp`; **0** application `LoadImage` / `StartImage`. Hooks are `BeforeConsole`, `AfterConsole`, `PriorityBoot` (Boot Manager menu only), `UnableToBoot`; `BootManager()` at `:237` calls `UpdateAcpiTables()`. |
| Effective marble `DeviceBootManagerLib` = `Silicon/Qualcomm/QcomPkg/Library/PlatformBootManagerLib/PlatformBootManager.c` (`QcomPkg.dsc.inc:36`) | **0** `charger`; `AfterConsole` only signals `gUsbControllerInitGuid`/`gSdCardInitGuid`; `OnDemandConInConnect` only `gUsbControllerInitGuid`; `BdsEntry` only `ProtectRfsSharedArea()`. |
| `ReadyToBoot` handlers across `Silicon/` + `Common/` | **6** files register one; **0** mention `charger`/`DefaultChargerApp` and **0** call `LoadImage`/`StartImage` (errata patch, advanced logger, var policy, display engine, Nvidia support, WHEA/BERT). The only `Silicon/` one is `KernelErrataPatcherLib.c:191`. |

**Gate:** 0/85 launch precedent + 0 buildable string consumers + a prebuilt-only
QcomBds means there is **no ≥90% Silicium-proven hook** to add. Per the track
gate, **no launch hook is invented**; no `QcomBds` is swapped or added; `BdsDxe`
stays. `QcomChargerApp` remains manually reachable through the Boot Manager.
Milestone and decision record: [`pd-track.md`](pd-track.md).

## 7. `rea` status

`rea doctor`: ghidra/hopper/IDA unavailable on this host, so no procedure
pseudocode was produced. Evidence above is strings + DEPEX + cfg + FV/UI
presence + stock/Binaries identity. Re-run `rea decompile` when
`GHIDRA_INSTALL_DIR` is set.
