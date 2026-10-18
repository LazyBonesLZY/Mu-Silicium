# marble UEFI — Linux boot track (LinuX / DtPlatform / BdsDxe)

Date: 2026-10-19 Asia/Shanghai. Scope: **Linux boot only** under the Mu
`BdsDxe` boot manager (no `QcomBds` swap). Gate: **≥90% static only**. No
on-device evidence is claimed; the repo `Status.md` Linux Boot row stays `❌`.

This file is the Linux-track companion to
[`static-blockers.md`](static-blockers.md) §“Linux Boot” and
[`status-gaps.md`](status-gaps.md) §4. It records the *verified* static chain,
the FDT pin, the command-line model, how a Linux boot option is reached under
`BdsDxe`, and the residuals that keep the row `❌`.

## Verdict

**ACCEPT the existing Linux wiring; no ≥90% firmware bug found in this pass.**
The DT handoff chain is statically proven end to end (FV and packaged image),
the default firmware preference is DT, and `BdsDxe` is kept by design. The
remaining work is a documented pin/cmdline/boot-option posture plus on-device
validation. **No `Status.md` flip.**

## Verified static chain

```
marble.fdf:104  INF EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf
marble.fdf:105  FILE FREEFORM = 25462CDA-221F-47DF-AC1D-259CFAA4E326 {
marble.fdf:106    SECTION RAW = marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb
marble.fdf:107    SECTION UI  = "DeviceTreeBlob"
                }
        │
        ▼  GetSectionFromAnyFv (gDtPlatformDefaultDtbFileGuid = 25462CDA-…)
DtPlatformDxeEntryPoint
  DtPlatformLoadDtb()                       (DxeDtPlatformDtbLoaderLibDefault.c)
  DtAcpiPref variable absent → PcdDefaultDtPref = TRUE  (EmbeddedPkg.dec:189)
  gBS->InstallConfigurationTable(gFdtTableGuid, Dtb)     (DtPlatformDxe.c:209)
        │
        ▼  gFdtTableGuid = b1b621d5-f19c-41a5-830b-d9152c69aae0 (MdePkg.dec:634)
Linux arm64 EFI stub
  fdt = get_efi_config_table(DEVICE_TREE_GUID)  (libstub/fdt.c:368)
  update_fdt(): sets /chosen/bootargs only if cmdline non-empty (fdt.c:88-93)
  kernel setup_arch → acpi_boot_table_init() (arch/arm64/kernel/acpi.c:198)
        │
        ▼
BdsDxe (DXE.inc:55, APRIORI.inc:77) boots the ESP EFI stub / bootloader
```

`QcomBds` is **not** present: `grep -c QcomBds` over `FVMAIN.Fv` = **0**;
`LinuxLoader` appears once in the whole FV, as ASCII inside the embedded
`uefiplat.cfg` RAW (`DefaultBDSBootApp = "LinuxLoader"`), with **no**
`LinuxLoader` module and **no** UTF-16 UI. That key is therefore inert under
`BdsDxe` (already recorded in `bds-qcombds-analysis.md` / `re-stock-uefi.md`).

## What was verified this pass (Linux only)

| Claim | Conf. | Evidence |
|:------|:-----:|:---------|
| `FdtBlob` DTB is byte-identical to a fresh build from `FdtBlob/Source.txt` | **≥95%** | Rebuilt with `scripts/build-marble-dtb.sh` using `SOURCE_TXT=FdtBlob/Source.txt` and a temp output; `sha256` of rebuild == `a242627fcf21adaa2ff378450bca7bef07eec8868d6fdda682ecf65a7a5cd6ff` == committed blob (`cmp` identical) |
| Pinned DTB is in the build FV under the FREEFORM GUID | **≥95%** | `FVMAIN.Fv` contains GUID `25462CDA-221F-47DF-AC1D-259CFAA4E326` @ `0x49b358` and the exact DTB @ `0x49bb14` (`sha256` match) |
| Pinned DTB reaches the *packaged* `Mu-marble.img` | **≥90%** | `Mu-marble.img` (sha256 `f896e619…`) bootimg gzip payload == `SILICIUM_UEFI.fd-bootshim` (sha256 `f5ab34b4…`); `SILICIUM_UEFI.fd` == `FVMAIN_COMPACT.Fv` (sha256 `8409e38d…`); the LZMA-nested `FVMAIN` decompressed from `FVMAIN_COMPACT.Fv` (6,627,336 B) contains the GUID and the exact DTB |
| Default firmware preference is DT, and the DT config table is installed | **≥90%** | `DtPlatformDxe.c:148/164` selects `DT_ACPI_SELECT_DT` when the `DtAcpiPref` variable is absent/invalid and `PcdDefaultDtPref=TRUE` (`EmbeddedPkg.dec:189`; not overridden in `PalimaPkg.dsc.inc` / `marble.dsc`); only the DT branch calls `InstallConfigurationTable (&gFdtTableGuid, Dtb)` at `:209` |
| Linux picks the DT over ACPI by default when a real DT is present | **≥90%** | `arch/arm64/kernel/acpi.c:198-209`: ACPI is enabled only for `acpi=on`/`acpi=force` or when `dt_is_stub()` is true; `dt_is_stub()` returns false for any tree with non-`/chosen` nodes (`:72-88`), and the marble DTB is a full tree |
| `BdsDxe` (kept) + Boot Manager Menu are the BDS path, `QcomBds` absent | **≥90%** | `DXE.inc:55`, `APRIORI.inc:77`; `FVMAIN.Fv` has UTF-16 `BdsDxe` + `BootManagerMenuApp`, **0** `QcomBds`; decision rationale in `bds-qcombds-analysis.md` (85/85 Silicium `BdsDxe`, 0 `QcomBds`) |
| Stock `uefiplat.cfg` / `BDS_Menu.cfg` RAW embeds with stock GUID/UI | **≥95%** | `RAW.inc:271-279` GUIDs `DDE58710-…` / `A91D838E-…`; `cmp`-identical to `notes/stock-re/carved/` (`docs/stock-fw-re.md` Findings A/E) |

## FDT pin status (drift is peripheral-only)

- `FdtBlob/Source.txt` = `REPO: https://github.com/iLtanaka/linux-marble` /
  `COMMIT: c9f87aac17d306786d1d15f67d8bdd226770e27a`.
- The local kernel tree is clean but its **HEAD is `91af1bd83`** (4 commits
  ahead of the pin). `git diff c9f87aac..HEAD -- …/sm8475-xiaomi-marble.dts`
  = **279 insertions / 8 deletions**, all *peripheral*:
  - additions: earpiece GPIO-LED, FPC/Goodix fingerprint nodes,
    `xiaomi-fingerprint` hub, PM8350C L1/L6 rails + `vdd-l1-l12-supply` /
    `vdd-l6-l9-l11-supply`, NFC (`i2c9 nq@28`), IR.
  - deletions: the old `speaker-earpiece-switch-hog` gpio-hog (replaced by the
    LED) and one `audio-routing` line.
  - **No** change to UFS, `framebuffer@b8000000`, `/chosen`, `memory@…`,
    remoteproc, or USB nodes.
- Therefore the pin is a **stability pin, not silent dirty-tree drift**: the
  committed blob matches the pin exactly, and the pin-to-HEAD delta does not
  affect reaching userspace. Bumping the pin to `91af1bd83` would only add
  peripheral nodes and is **not** a ≥90% Linux-boot fix, so no firmware change
  is made. Recorded as a deliberate residual.

## Command-line model (`cmdline` / `extlinux`)

**`extlinux` is not consumed by UEFI.** `grep -ri extlinux` over the whole
Mu-Silicium tree returns nothing; `BDS_Menu.cfg` is a `QcomBds` menu format and
is never read by `BdsDxe`. `extlinux.conf` remains a U-Boot artifact. Under
this firmware there are exactly two cmdline sources:

1. **EFI LoadOptions** of the boot entry (a bootloader on the ESP such as
   GRUB/systemd-boot, or a `Boot####` entry with optional data).
   The stub's `efi_handle_cmdline()` (`libstub/efi-stub.c:115-151`) reads it.
2. **`/chosen/bootargs` in the UEFI-passed DTB** when LoadOptions is empty.
   `update_fdt()` only overwrites `bootargs` when `cmdline_ptr` is non-empty
   (`libstub/fdt.c:88-93`).

The pinned DTB carries a **postmarketOS cmdline** hard-coded in the DTS
(`sm8475-xiaomi-marble.dts:146`):

```
PMOS_NOSPLASH console=tty0 console=ttyMSM0,115200n8 earlycon loglevel=8
ignore_loglevel printk.devkmsg=on pstore.compress=none log_buf_len=2M
msm_geni_serial.con_enabled=0
```

Consequence: if the ESP EFI stub is launched with **no** LoadOptions, the
kernel receives the pmOS command line above (no `root=`, no user options). Any
real distro install must supply its own cmdline either via an ESP bootloader or
via a `Boot####` entry with optional data. `acpi=off` is **not** required:
per `arch/arm64/kernel/acpi.c:207-209` a real DT makes DT win by default, so
the dual ACPI+DT FDF does not endanger the DT handoff. (The earlier
“may need `acpi=off`” note in `status-gaps.md` §4 is superseded by this more
precise statement.)

## Boot option docs (how Linux is reached under `BdsDxe`)

The Silicium platform boot manager registers fixed options only
(`MsBootOptionsLib.c:240-262`): `Internal Storage` / `USB Storage`
(`gMsBootPolicyFileGuid` with `SSD`/`USB` optional data), `FFU Mode`, and the
`PlatformBootOptionsLib` list — which is the **Null** implementation in this
tree (`SiliciumPkg.dsc.inc:239`), so it contributes nothing. There is no
`LinuxLoader` module and no `extlinux` reader.

The working Linux path under `BdsDxe` is therefore the generic UEFI one, and it
must be documented for the Linux track:

1. Put the EFI stub / bootloader on the ESP at the removable-media path
   `\EFI\BOOT\BOOTAA64.EFI` (or a distro path such as `\EFI\<distro>\grubaa64.efi`).
2. Reboot; hold **Volume Up** to enter the `BootManagerMenuApp` UI (the
   `[Volume Up] Boot Manager` string in `BootManager.c:35`), let the UI refresh
   boot options (`EfiBootManagerRefreshAllBootOption` in `BootManagerUiLib`),
   and select the ESP entry. Distro bootloaders on the ESP then chainload the
   kernel and set the cmdline via LoadOptions.
3. The firmware hands the kernel the pinned DT via the FDT config table
   (verified above). `DefaultBDSBootApp = "LinuxLoader"` is **not** the
   mechanism — it is inert under `BdsDxe` and is kept only because it is part
   of the stock `uefiplat.cfg` RAW.

This is the same pattern as the sibling Linux-boot Silicium ports; no
marble-specific QcomBds switch or LaunchApp hook is invented.

## Residual gaps (why the row stays `❌`)

| Gap | Static posture | ≥90% action? |
|:----|:---------------|:-------------|
| On-device Linux boot to userspace | Not statically knowable | none |
| ESP boot option discovery / Boot Manager selection | UI present (`BootManagerMenuApp` UTF-16 UI in FV); no on-device run | document only |
| Kernel cmdline for a real distro | EFI LoadOptions vs DTB `bootargs` (pmOS) proven; no root= in DTB | document only (user/bootloader responsibility) |
| `DtAcpiPref` UEFI variable set to ACPI suppresses the FDT table | Default is DT and only the DT branch installs `gFdtTableGuid`; variable is non-persistent per stock (`AllowNonPersistentVarsInRetail=0x1`) | document only; recover by clearing the variable if a prior HII choice stuck |
| FDT pin `c9f87aac` vs kernel HEAD `91af1bd` | Peripheral-only delta (fingerprint/NFC/IR/earpiece/LED + PMIC supplies); blob byte-identical to pin | no (stability pin) |
| `uefiplat.cfg`/`BDS_Menu.cfg` placement one FV level higher than stock | GUID/UI/RAW identical; `RAW.inc` lives in `FvMain`, stock `uefiplat.cfg` at top-level `uefi.img` | document only |
| PIL Reserved / Display Demura overlap | Stock-inherent, aligned in `201614d` (`MemoryMapLib.c:15-16`); display base/size match the DTB | documented in `mainline-crosscheck.md` |

## Evidence commands (reproducible)

```sh
# DTB matches the pin
SOURCE_TXT=<copy of FdtBlob/Source.txt> scripts/build-marble-dtb.sh /tmp/pin.dtb
sha256sum /tmp/pin.dtb Platforms/Xiaomi/marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb

# FV contains GUID + exact DTB; packaged image chain
sha256sum Mu-marble.img Build/marblePkg/RELEASE_CLANGPDB/FV/SILICIUM_UEFI.fd-bootshim \
          Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN_COMPACT.Fv \
          Build/marblePkg/RELEASE_CLANGPDB/FV/FVMAIN.Fv \
          Platforms/Xiaomi/marblePkg/FdtBlob/sm8475-xiaomi-marble.dtb
# LZMA-nested FVMAIN from FVMAIN_COMPACT.Fv contains GUID 25462CDA-… and the DTB

# pin drift is peripheral-only
git -C /workspace/marble/src/linux-marble diff --stat \
    c9f87aac17d306786d1d15f67d8bdd226770e27a..HEAD \
    -- arch/arm64/boot/dts/qcom/sm8475-xiaomi-marble.dts
```

## Commit policy

Docs-only for this pass. **No** `marble.dsc` / `marble.fdf` / `DXE.inc` /
`RAW.inc` / `FdtBlob` / `MemoryMapLib.c` change, and **no** repo `Status.md`
flip. The Linux Boot row stays `❌` until an on-device boot is observed.
