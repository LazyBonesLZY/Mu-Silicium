# WoA / Windows Boot track — marble (Poco F5, SM7475-AB, Palima)

Date: 2026-10-19 Asia/Shanghai. **ALL STATIC.** No on-device validation. No upload.
Dedicated track: **Windows/WoA only** — deliberately kept separate from the Linux
boot narrative. `Status.md` `Windows Boot` stays **❌**.

## 0. Decision (leader summary)

| Item | Result | Confidence |
|------|--------|-----------|
| marble ACPI table set vs pong (Windows ✅ Palima sibling) | `AcpiTables.inf` binary list identical; `DSDT.aml` **byte-identical** (md5 `d485f2638d84aaf3a547b878e79e6319`) | ≥95% |
| SMBIOS PCDs (Type 1/4 population) | Present, device-correct (`marble.dsc` + `PalimaPkg.dsc.inc` `SOC_TYPE=2`) | ≥95% |
| UFS ACPI node + runtime patch | `UFS0` (`QCOM24A5`) present; `UpdateAcpiTables()` patches `EMUL`/`STOR`/`SUFS`/`PUS3`/`SUS3` … | ≥95% |
| UFS block I/O for the ESP (winload source) | `UFSDxe` (patched) + `DiskIo` + `PartitionDxe` + `Fat` all in FVMAIN, APRIORI-ordered | ≥90% |
| WoA boot-manager path | `BdsDxe` + Silicium `PlatformBootManagerLib` (DuoWoA/Microsoft heritage) → `MsBootPolicy` → default `\EFI\BOOT\BOOTAA64.EFI` | ≥90% |
| Secure-boot policy handling for WoA | `SecureBootHandlerLib` probes `\EFI\Microsoft\Boot\bootmgfw.efi`; `ENABLE_SECUREBOOT=0` in the shipped build | ≥95% |
| Second-pass sibling hunt (effective-FV set, §9) | **No WoA-boot gap.** Only delta is `ProjectInfoDxe`/`UCDxe` (APRIORI-only ⇒ absent from FV); refuted as a WoA blocker | ≥90% |
| **≥90% static firmware gap found?** | **None.** Docs only; no fake AML, no FV churn | ≥90% |
| Windows Boot Status flip | **Blocked.** winload/kernel/drivers/SecureBoot policy are on-device | — |

> **Second pass note.** §9 recomputes the sibling comparison over the
> *effective FV module set* (`DXE.inc` + explicit `marble.fdf` `INF`s), because
> `APRIORI.inc` here is a **dispatch-order list only** and does not itself place
> a module in the FV. It finds one real, previously-unreported inconsistency
> (`ProjectInfoDxe`/`UCDxe` are APRIORI-only), proves it harmless and non-WoA,
> and re-confirms the static ceiling. Update to §2.1: “APRIORI/DXE same as
> pong” is true for dispatch order, but marble's `DXE.inc` **does** differ from
> venus/vili/b4q by those two prebuilt modules.

No code change, no rebuild. Artifact unchanged: `Mu-marble.img` 1,728,512 B,
SHA256 `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`.

## 1. Sources

- Parent review §3 Windows: `/workspace/marble/uefi/notes/stock-re/REVIEW-uefi-marble-FULLCHAIN.md` (lines 93–107).
- [`host-windows-re.md`](host-windows-re.md) §3 (stock ACPI carve = 0 tables; pong parity).
- [`status-gaps.md`](status-gaps.md), [`static-blockers.md`](static-blockers.md) (existing ceiling).
- Stock carve: `/workspace/marble/uefi/notes/stock-re/carved/` (nested FV, `stock-uefi-modules.txt`).
- `Silicium-ACPI/Platforms/{Xiaomi/marble,Nothing/pong,Samsung/b4q}/`; `Silicium-ACPI/Silicon/Qualcomm/Palima/`.
- `Silicon/Qualcomm/PalimaPkg/Library/AcpiTableUpdateLib/AcpiTableUpdate.c`.
- `Silicon/Silicium/SiliciumPkg/Library/{BootManagerLib,MsBootOptionsLib,SecureBootHandlerLib,MsBootPolicyLib}/`.
- `Common/Mu/PcBdsPkg/MsBootPolicy/`; `Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv[.txt]`.

Community/external note: outbound `web_fetch`/`web_search` is unavailable in this
session (hostnames resolve to non-public addresses, no search API key). Community
evidence is therefore taken from the in-tree Silicium sibling signals
(`Status.md` rows) and the parent review; no external claim is asserted here.

## 2. ACPI parity vs Windows-✅ Silicium ports

### 2.1 pong (Nothing Phone 2, SM8475, Palima) — the correct comparator

marble is `SM7475-AB` / Palima, so pong is the closest Windows-✅ sibling.

| Artifact | marble | pong | Match |
|----------|--------|------|-------|
| `AcpiTables.inf` `[Binaries]` list | local `DSDT.aml`, `Common/SSDT`, Palima `APIC/DBG2/FACP/GTDT/PPTT` | identical | ✅ byte-for-byte |
| `DSDT.aml` | `d485f2638d84aaf3a547b878e79e6319` | `d485f2638d84aaf3a547b878e79e6319` | ✅ identical |
| `Decompiled/DSDT.dsl` | — | `diff` empty | ✅ identical |
| ACPI driver set in FDF | `AcpiTableDxe` + `AcpiPlatformDxe` + `ACPI TABLE marble/AcpiTables.inf` | `ACPI TABLE pong/AcpiTables.inf` | ✅ |
| APRIORI/DXE | `IortDtDxe` first; UFS/USB/XHCI order | same | ✅ (see §3) |
| Runtime DSDT patch | `PalimaPkg` `AcpiTableUpdateLib` | same library | ✅ |
| SMBIOS PCD pattern | Manufacturer/Model/Retail/Board + Palima Processor PCDs | same pattern | ✅ (device strings differ) |

`marble.dsc` ACPI/PEI section and `marble.fdf` differ from pong only in package
name, FDT blob and comments (`diff pong.fdf marble.fdf`).

### 2.2 Other Windows-✅ ports are different SoC families

`Silicium-ACPI/Platforms`: r0q uses Waipio; aston and qrd8550 use Kailua
(qrd8550 adds `DSDT_QRD` + MCFG/IORT/CSRT); bale_b / peridot use Palawan
(`DSDT_Minimal`); b4q uses a hand-written Palima `DSDT.asl`. Only pong
(same Palima family, same table set) is a like-for-like comparator; the others
confirm "Windows ✅ exists on Silicium" but add no table delta marble can lift
(the Kailua MCFG/IORT/CSRT set is SoC-specific and pong boots Windows without
it).

### 2.3 Observation (not a gap) — `UFS0` shape differs from b4q

b4q's hand-written Palima DSDT gates `UFS0._STA` on `STOR == 1` and sets
`_CCA = 1`; marble/pong use `_STA → 0x0F` unconditionally and `_CCA = 0` with an
`EMUL` alias. Both carry the same root names that `UpdateAcpiTables()` fills
(`STOR`, `SUFS`, `EMUL`, …), and **pong is Windows ✅ with marble's exact DSDT**,
so this is a style/coherency choice, not a boot blocker. No AML change clears
≥90%.

## 3. UFS — the storage path winload depends on

### 3.1 ACPI node (`Silicium-ACPI/Platforms/Xiaomi/marble/Decompiled/DSDT.dsl`)

```
Device (UFS0)      _HID "QCOM24A5", _UID 0, _CCA 0
                   _CRS: Memory32Fixed 0x01D84000 / 0x15000, IRQ 0x129
                   Alias (^EMUL, EMUL)
  Device (DEV0)    _ADR 0x08, _RMV 0
```

`Scope (_SB)` declares all names the runtime updater patches:
`STOR=1, SUFS=0xFFFFFFFF, PUS3=1, SUS3=0xFFFFFFFF, EMUL=MMIO(0x01FC8004)&3, …`
(Palima `AcpiTableUpdateLib` `UpdateAcpiTables()`; called from
`PlatformBootManagerBdsEntry()` in Silicium `BootManagerLib`).

### 3.2 UEFI block I/O + FAT (ESP visibility)

`Binaries/marble/QcomPkg/Drivers/UFSDxe/UFSDxe.inf` selects
`PE32|UFSDxe.patched.efi`, `Depex TRUE`. The 8-byte patch is the same
`MOVZ W1,#1 ; BL` rewrite used on the Windows-✅ siblings (marble file offset
39553, pong 39729, b4q 43945; decoded from `cmp -l`/`od`), i.e. no
marble-specific divergence.

Module GUIDs verified present in `Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv.txt`:

| Module | `FILE_GUID` in FVMAIN | Role for WoA |
|--------|------------------------|--------------|
| `UFSDxe` | `0D35CD8E-97EA-4F9A-96AF-0F0D89F76567` | UFS block I/O |
| `DiskIoDxe` | `6B38F7B4-AD98-40E9-9093-ACA2B5A253C4` | Block I/O |
| `PartitionDxe` | `1FA1F39E-FEFF-4AAE-BD7B-38A070A3B609` | GPT/MBR |
| `Fat` (EnhancedFatDxe) | `961578FE-B6B7-44C3-AF35-6BC705CD2B1F` | Simple File System |
| `EnglishDxe` | — | FAT filename collation |
| `BdsDxe` | `6D33944A-EC75-4855-A54D-809C75241F6C` | boot manager |
| `MsBootPolicy` | `50670071-478F-4BE7-AD13-8754F379C62F` | WoA boot policy app |

`APRIORI.inc` order: `DiskIo` (43) → `Partition` (44) → `English` (45) →
`Sdcc` (47) → `UFSDxe` (48) → `Fat` (50), i.e. UFS and its filesystem are up
before `BdsDxe` (line 77).

## 4. ESP / BCD / winload contract — firmware vs on-device

### 4.1 What the UEFI firmware must expose (all present, ≥90% static)

1. **UFS block device** (`UFSDxe`, patched) + GPT parse (`PartitionDxe`) +
   **FAT Simple File System** (`Fat`). Windows Setup formats the ESP as FAT32;
   `SimpleFileSystem` on that partition is the only "file access" the firmware
   needs (`BootManagerLib` consumes it).
2. **Boot manager**: `BdsDxe` bound to
   `PlatformBootManagerLib|SiliciumPkg/Library/BootManagerLib/BootManagerLib.inf`
   (`SiliciumPkg.dsc.inc:238`). `PlatformBootManagerBeforeConsole()` calls
   `MsBootOptionsLibRegisterDefaultBootOptions()`, which registers
   `Internal Storage` (optional data `"SSD"`) and `USB Storage` (`"USB"`)
   against `gMsBootPolicyFileGuid = 50670071-478F-4BE7-AD13-8754F379C62F`.
3. **WoA boot policy**: `MsBootPolicy` (in FV) with parameter `"SSD"` selects a
   **non-USB `SimpleFileSystem`** handle and calls `EfiBootManagerBoot()` on a
   device-path-only option. `MdeModulePkg/Library/UefiBootManagerLib/BmBoot.c`
   expands that to `EFI_REMOVABLE_MEDIA_FILE_NAME_AARCH64` =
   **`\EFI\BOOT\BOOTAA64.EFI`** (`BmBoot.c:1133`, `:1209`; constant from
   `MdePkg/Include/Uefi/UefiSpec.h:2270`). Windows Setup writes that fallback
   file on the ESP alongside `\EFI\Microsoft\Boot\bootmgfw.efi`.
4. **Secure-boot policy handling for WoA**:
   `SecureBootHandlerLib/SecureBootHandler.h` hard-codes
   `\EFI\Microsoft\Boot\bootmgfw.efi` and `\EFI\Microsoft\Boot\SiPolicy.p7b`.
   `SetupSecureBoot()` runs at BDS entry: with `ENABLE_SECUREBOOT=0`
   (`Build/.../TOOLS_DEF.AARCH64: CC_FLAGS … -D ENABLE_SECUREBOOT=0`) it
   deletes a stale `SiPolicy.p7b`; with `=1` it enrolls the Microsoft keys and
   installs the in-FV `SiPolicy.p7b`. ACPI/SMBIOS are unaffected by the choice.
5. **ACPI + SMBIOS**: DSDT/SSDT/APIC/FACP/GTDT/PPTT/DBG2 magics present in FVMAIN
   (`host-windows-re.md` Appendix A); `SmbiosDxe`
   (`F9D88642-0737-49BC-81B5-6889CD57D9EA`) + `SmBiosTableDxe`
   (`50A15B6F-E3A9-4192-9640-369CB367C4DE`) present, populated
   from `marble.dsc` + `PalimaPkg.dsc.inc`:
   `Xiaomi / Poco F5 / marble / Poco_F5_marble / Poco F5` and
   `Snapdragon (TM) 7+ Gen 2 @ 2.91 GHz` / `SM7475-AB`.
6. Base services already covered by earlier passes: RTC, timers, GOP/console,
   runtime variables, `DxeCore` dispatch.

### 4.2 What is **not** firmware and stays on-device (out of scope)

- The **BCD store** (`\EFI\Microsoft\Boot\BCD`) is created/parsed by
  `bootmgfw.efi`; UEFI does not read it. The firmware only loads
  `BOOTAA64.EFI`/`bootmgfw.efi` from FAT.
- **`winload.efi`** (`\Windows\System32\winload.efi`), `winresume`, kernel and
  drivers are loaded by `bootmgfw` from the Windows partition; no UEFI change can
  prove them statically.
- **Windows UFS/USB/PCIe device drivers** (Windows may need a UFS driver or the
  "Modding UFS" setup), activation, and the Secure Boot policy as seen by
  Windows (the community build ships Secure Boot off).
- Whether the ESP actually enumerates, whether the UFS patch behaves on silicon,
  and whether winload reaches a desktop — all on-device.

## 5. ≥90% static firmware-gap audit — result: **none**

| # | Check | Evidence | Verdict |
|---|-------|----------|---------|
| 1 | ACPI INF resolves same tables as pong | `diff` `AcpiTables.inf` | PASS |
| 2 | Carried DSDT identical to Windows-✅ pong | md5 `d485f263…` | PASS |
| 3 | Runtime DSDT names patched for Palima | `AcpiTableUpdate.c` `UpdateAcpiTables()` | PASS |
| 4 | UFS ACPI node present | `DSDT.dsl` `UFS0`/`QCOM24A5`/`_CRS` | PASS |
| 5 | UFS DXE present and INF points at patched PE32 | FV GUID `0D35CD8E…`; INF `PE32\|UFSDxe.patched.efi` | PASS |
| 6 | UFS patch matches Windows-✅ siblings | `cmp`/`od` byte pattern identical | PASS |
| 7 | Block I/O + FAT present before BDS | FV GUIDs; `APRIORI.inc` order | PASS |
| 8 | WoA boot manager path wired | `BootManager.c` `MsBootOptionsLibRegisterDefaultBootOptions` | PASS |
| 9 | `MsBootPolicy` GUID matches `gMsBootPolicyFileGuid` | INF `50670071-478F-4BE7-AD13-8754F379C62F` | PASS |
| 10 | Menu PCD matches `BootManagerMenuApp` | `EEC25BDC-67F2-4D95-B1D5-F81B2039D11D` | PASS |
| 11 | Firmware default path is the WoA fallback | `BmBoot.c` `EFI_REMOVABLE_MEDIA_FILE_NAME_AARCH64` | PASS |
| 12 | `bootmgfw`/`SiPolicy` ESP paths referenced | `SecureBootHandler.h` | PASS |
| 13 | Secure-boot mode coherent with community WoA | `ENABLE_SECUREBOOT=0` in build flags | PASS |
| 14 | SMBIOS populated | `SmbiosDxe` + `SmBiosTableDxe` GUIDs; PCDs | PASS |
| 15 | Stock Android FV has no marble AML to lift | 0 DSDT/SSDT/XSDT/RSDT/FACP/APIC (`host-windows-re.md` §3) | PASS (ceiling) |

Nothing meets the "implement a firmware fix" bar. Consistent with the parent
review: *no further static firmware P0 inventable for Host/Windows*.

## 6. Residuals (on-device; no Status ✅)

1. **UFS reads on silicon** — the patched `UFSDxe` cannot be proven to read the
   ESP without a device. (INF/PE32/patch verified; behavior not.)
2. **`\EFI\BOOT\BOOTAA64.EFI` present on a real ESP** and `bootmgfw`/BCD authored
   by Windows Setup.
3. **`winload.efi` + kernel + drivers + Secure Boot policy** — OS-side.
4. **Windows-side UFS/USB drivers** — see `Status.md` pong Windows OS rows and the
   Silicium "Modding UFS" guide referenced there.
5. **FV headroom** — FVMAIN `taken 0x651c48 / total 0x652000` (~99% full, ~952 B
   free); any future WoA module needs an FD/FV budget review first.

## 7. Artifact quality gate (this pass, unchanged build)

- FVMAIN total `0x652000`, taken `0x651c48`; 106 FFS files, unique GUIDs.
- ACPI magics in FV: DSDT/SSDT/APIC/FACP/GTDT/PPTT/DBG2 (`host-windows-re.md` Appendix A).
- Key WoA GUIDs present (table in §3.2) and `MsBootPolicy`/`BootManagerMenuApp` UUIDs consistent with their PCDs.
- `Mu-marble.img` unchanged this pass (docs only):
  1,728,512 B, SHA256 `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`.

## 8. Changes in this pass

Docs only: **this file**. No DXE/APRIORI/FDF/ACPI/DT edit (none cleared ≥90%),
no rebuild, no upload. `Status.md` `Windows Boot` stays ❌.

## 9. Second-pass sibling hunt — effective-FV membership (2026-10-19)

**Why a second pass.** §2–§5 compared the `APRIORI.inc` ∪ `DXE.inc` module
*union*. In this tree `APRIORI.inc` encodes **dispatch order only** — an `INF`
there does **not** place the module in the FV. FV contents come from `DXE.inc`
plus the explicit `INF` lines in `marble.fdf`. The union therefore hid modules
listed in `APRIORI.inc` but absent from `DXE.inc`. This pass re-ran the sibling
diff over the **effective FV set** (= `DXE.inc` ⊎ explicit FDF `INF`s) and
audited every APRIORI-only entry.

### 9.1 Comparators

| Port | SoC family | `Status.md` Windows | `DXE.inc` modules |
|------|-----------|:-------------------:|:-----------------:|
| marble | Palima (SM7475-AB) | ❌ | 83 |
| pong | Palima (SM8475) | ✅ | 83 |
| b4q | Palima (SM8475) | ✅ | 84 |
| venus | Lahaina | ✅ | 82 |
| ingres | Waipio | ✅ | 82 |
| vili | Lahaina | ✅ | 83 |
| alioth | Kona | ✅ | 83 |

Method: strip comments/path prefixes, take `INF …\.inf` from `DXE.inc`
(the FDF `INF`s are the same common set on every port: `SmbiosDxe`,
`SmBiosTableDxe`, `AcpiTableDxe`, `AcpiPlatformDxe`, `<port>/AcpiTables.inf`,
`IortDtDxe`, `DtPlatformDxe`, `RamManagerDxe`), and `comm` the sorted sets.

### 9.2 Effective modules a Windows✅ sibling has that marble's FV lacks

| Module(s) | pong (P) | b4q (P) | venus | ingres | vili | alioth | Binary role (strings) | WoA-boot role |
|-----------|:--------:|:-------:|:-----:|:------:|:----:|:------:|-----------------------|:-------------:|
| `ProjectInfoDxe` | — | — | ✔ | ✔ | ✔ | — | `EFI_GetProjectInfo` ADC/hw-id (MIUI project) | none |
| `UCDxe` | APRIORI-only | ✔ | ✔ | APRIORI-only | ✔ | — | `CipherProtocol`/`Hash`/`Mac`, HWIO, Npa | none |
| `NT_DeviceInfoDxe` | ✔ | — | — | — | — | — | Nothing-device info | none |
| `SamsungDxe/{Ccic,Muic,Chg,Redriver,SubPmic}Dxe` | — | ✔ | — | — | — | — | Samsung charging/MUIC/redriver | none |
| `AdcDxe`,`CipherDxe`,`HashDxe`,`MacDxe`,`PdcDxe` | — | — | — | — | — | ✔ | Kona ADC/crypto/PDC | none |

- Strict task criterion (“shared by ≥2 **Palima** Windows✅ ports”, i.e. both
  pong and b4q): **∅ — zero modules.**
- Broad criterion (“shared by ≥2 Windows✅ ports”): only
  **`ProjectInfoDxe`** (venus/ingres/vili) and **`UCDxe`** (b4q/venus/vili).
  Both are audited and refuted in §9.3.

### 9.3 New finding — `ProjectInfoDxe` + `UCDxe` are APRIORI-only ⇒ not in FV

This is a real, previously-unreported inconsistency, not a WoA gap:

- `APRIORI.inc` lists `Binaries/marble/QcomPkg/Drivers/{ProjectInfoDxe,UCDxe}`
  (lines 21 and 101) but marble's `DXE.inc` omits both, so their FFS files are
  **not** in `FVMAIN`. Cross-check: GUID `0A8D6360-7EF3-11EA-B20F-B3A524584400`
  (`ProjectInfoDxe`) and `5F0937CD-73F9-445E-B320-BB6FD5D3CBDE` (`UCDxe`) are
  **absent** from `FVMAIN.Fv.txt`/`Guid.xref`, yet **present** in the generated
  APRIORI file
  (`Build/…/FV/Ffs/FC510EE7-…FVMAIN/FC510EE7-…FVMAIN.Apri`).
  By contrast `IortDtDxe` is APRIORI-only but *is* in the FV because
  `marble.fdf` has an explicit `INF QcomPkg/Drivers/IortDtDxe/IortDtDxe.inf`.
- **Harmless for dispatch:** `MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c`
  `:1427-1443` walks the APRIORI GUID array and schedules a driver only when a
  discovered FFS file matches; an absent GUID is silently skipped (no hang, no
  assert). The FV/APRIORI is internally consistent enough to boot.
- **Not WoA-boot-critical — proven by Windows✅ comparators:**
  - pong (Palima, Windows✅) has **no** `ProjectInfoDxe` binary at all and lists
    `UCDxe` APRIORI-only too (same effective FV omission). So pong reaches
    Windows *without* either module.
  - b4q (Palima, Windows✅) has no `ProjectInfoDxe`; alioth (Windows✅) has
    neither.
  - Roles are unrelated to the boot chain: `ProjectInfoDxe` = MIUI
    project/hwid ADC reader; `UCDxe` = Qualcomm crypto (Cipher/Hash/Mac)
    driver. Neither provides UFS/block/`SimpleFileSystem`, BDS, ACPI or SMBIOS.
- **Infeasible as a casual FV add anyway:** `UCDxe.efi` = 176,128 B and
  `ProjectInfoDxe.efi` = 57,344 B vs FVMAIN headroom of **952 B**
  (`taken 0x651c48 / total 0x652000`). Adding them needs an FD/FV + BootShim
  budget change, i.e. exactly the FV churn §6.5 warns against, for no WoA gain.
- **Disposition:** housekeeping (add to `DXE.inc` only if the FV is resized for
  another reason). **Does not clear ≥90% for WoA boot; no code change.**

### 9.4 `DisplayReEnablerDxe` — refuted as a delta (director pre-check)

- pong `DXE.inc:76` is commented out: `#INF QcomPkg/Drivers/DisplayReEnablerDxe/…`
  and sits **inside** `!if $(USE_CUSTOM_DISPLAY_DRIVER) == 1` (pong `pong.dsc:26`
  `= 1` ⇒ custom `DisplayDxe`; marble `marble.dsc:27` `= 0` ⇒ `SimpleFbDxe`).
  It is **not** in pong's effective FV; `DisplayReEnablerDxe.inf` is a
  display-path driver (`Silicon/Qualcomm/QcomPkg/QcomPkg.dsc.inc:55`) with no
  storage/BDS/ACPI role.
- Verdict: **confirm the director pre-check — refuted as a ≥90% WoA addition.**
  Adding it would drag marble onto the custom-display path (framebuffer model
  change), not advance Windows boot.

### 9.5 SMBIOS / SecureBoot re-confirmed (device-independent)

- SMBIOS is end-to-end baked into the built FV: `SmBiosTableDxe.efi` contains
  `Poco F5` / `marble` / `SM7475-AB`; `FVMAIN.Fv` too (`Xiaomi`, `Poco F5`,
  `Poco_F5_marble`, `Snapdragon (TM) 7+ Gen 2`). All 7 `PcdSmbios*`
  referenced by `SmBiosTable.c` are set (5 in `marble.dsc`, processor model/part
  in `PalimaPkg.dsc.inc` `SOC_TYPE=2`).
- SecureBoot is a global build flag, not per-port: `build_uefi.py:227`
  `ENABLE_SECUREBOOT={0|1}` with default **0**
  (`build_active_devices.sh:27`, opt-in `-s`); `marble`'s
  `TOOLS_DEF.AARCH64` confirms `-D ENABLE_SECUREBOOT=0`. The built `BdsDxe.efi`
  carries the wide paths `\EFI\BOOT\BOOTAA64.EFI`,
  `\EFI\Microsoft\Boot\bootmgfw.efi`, `\EFI\Microsoft\Boot\SiPolicy.p7b`.
  No marble-specific divergence.

## 10. Static ceiling and goal disposition — **blocked**

**Static ceiling reached.** Across two passes, every statically checkable
firmware input to the WoA chain is at parity with ≥2 Windows✅ siblings and no
firmware delta clears ≥90% for *Windows boot*:

| Angle | Result |
|-------|--------|
| ACPI table list vs pong/b4q | identical `AcpiTables.inf` `[Binaries]`; DSDT md5 `d485f263…` ≡ pong |
| Runtime DSDT patch | shared `PalimaPkg` `AcpiTableUpdateLib`; `UFS0`/`URS0`/`USB0`/`UFN0` present |
| UFS + DiskIo + Partition + Fat + BdsDxe | all in `FVMAIN` (GUIDs §3.2); APRIORI order `DiskIo→Partition→English→Sdcc→UFSDxe→Fat→BdsDxe` ≡ pong/b4q |
| UFS 8-byte patch | same `MOVZ W1,#1 ; BL` rewrite at each sibling's site |
| SMBIOS / SecureBoot | end-to-end confirmed (§9.5), device-independent |
| Sibling DXE gaps (effective FV) | none for ≥2 Palima ports; only non-WoA `ProjectInfoDxe`/`UCDxe` (§9.3) |
| Stock Android FV AML to lift | 0 DSDT/SSDT/XSDT/RSDT/FACP/APIC (`host-windows-re.md` §3) |

What remains is **not** firmware and cannot be cleared statically:
`winload.efi` + kernel + Windows drivers (UFS/PCIe/USB), the BCD authored by
Windows Setup, Secure Boot policy as seen by Windows, and actual ESP
enumeration/`bootmgfw` execution. **No fake AML, no invented driver, no FV
churn.** Therefore the Windows Boot goal is **blocked on the static ceiling**
(on-device evidence required); `Status.md` `Windows Boot` stays ❌.

Artifact unchanged this pass (**docs only**): `Mu-marble.img` 1,728,512 B,
SHA256 `f896e61992c7f06a17df74639b9f6f8443054ce1720abe15a31c011ea02352f6`.
