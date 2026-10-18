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
| **≥90% static firmware gap found?** | **None.** Docs only; no fake AML, no FV churn | ≥90% |
| Windows Boot Status flip | **Blocked.** winload/kernel/drivers/SecureBoot policy are on-device | — |

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
