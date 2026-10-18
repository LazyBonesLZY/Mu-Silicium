# marble UEFI × mainline DTS cross-check

> Location note: the goal asked for `/workspace/marble/uefi/notes/mainline-crosscheck.md`,
> but the DSH file sandbox is read-only outside the Mu-Silicium session workspace, so this
> copy lives in-repo and is committed with the marble changes. An identical copy was
> attempted at the requested sibling path and rejected by the sandbox.

- Date: 2026-10-19
- Mu-Silicium: `Platforms/Xiaomi/marblePkg` (PalimaPkg, `SOC_TYPE = 2` = SM7475-AB)
- Mainline source (read-only): `git -C /workspace/marble/src/linux-marble show c9f87aac17d306786d1d15f67d8bdd226770e27a:arch/arm64/boot/dts/qcom/sm8475-xiaomi-marble.dts`
- The kernel working tree had local NFC/IR additions (`git diff` +78 lines); all values
  below come from the **pinned commit**, not the dirty tree.

## Display / framebuffer

| Item | Mainline DTS (pinned) | Mu marblePkg | Verdict |
|------|-----------------------|--------------|---------|
| framebuffer node | `framebuffer@b8000000` (`simple-framebuffer`) | `SimpleFbDxe` locates region by name | OK |
| base | `0xb8000000` | `{"Display Reserved", 0xB8000000, 0x02B00000}` | OK |
| size | `0x02b00000` | `0x02B00000` | OK |
| width | `1080` | `PcdFrameBufferWidth = 1080` | OK |
| height | `2400` | `PcdFrameBufferHeight = 2400` | OK |
| stride | `(1080 * 4)` = 4320 = `0x10E0` | `ColorDepth = 32` → 1080×4 = 4320 | OK |
| format | `a8r8g8b8` | GOP 32-bit BGRA (SimpleFbDxe) | OK |
| reserved-memory `splash_region@b8000000` | `0xb8000000 / 0x02b00000`, `no-map` | same window via `Display Reserved` | OK |

- `Silicon/Silicium/.../SimpleFbDxe/SimpleFb.c::GetFrameBufferInfos()` reads the
  `"Display Reserved"` descriptor and the three `PcdFrameBuffer*` values; all three
  match mainline. No change needed.
- Panel binding `xiaomi,marble-m16t-36-02-0a` (mainline) corresponds to the device
  binary `Binaries/marble/RawFiles/Panel_M16t_36_02_0a_amoled_dsc_vid.xml`, which is
  present. `marble.dsc` sets `USE_CUSTOM_DISPLAY_DRIVER = 0`, so UEFI uses the simple
  framebuffer (continuous splash) rather than the DSI panel blob; this is the intended
  path and matches the DTS `simple-framebuffer`.

## Volume / power keys

| Function | Mainline (pinned) | UEFI | Verdict |
|----------|-------------------|------|---------|
| Volume Up | `gpio-keys` / `pm8350_gpios` GPIO6, `GPIO_ACTIVE_LOW`, pinctrl `vol_up_n` (pull-up) | `ButtonsDxe` blob (PMIC keys) | OK |
| Volume Down | `pon_resin` `linux,code = KEY_VOLUMEDOWN` | `ButtonsDxe` blob | OK |
| Power | `pon_pwrkey` `status = okay` | `ButtonsDxe` + `PwrBtnShutdownFlag = 0x0` | OK |

- `ConfigurationMapLib.c` has `{"PwrBtnShutdownFlag", 0x0}` exactly like stock
  `uefiplat.cfg`. Key *addresses* live in the prebuilt `ButtonsDxe`/`PmicDxe` blobs,
  not in the device package, so there is nothing device-specific to fix here.

## UFS

| Item | Mainline (pinned) | UEFI | Verdict |
|------|-------------------|------|---------|
| HC node | `ufshc@1d84000` | `UFSDxe` blob | OK |
| PHY node | `phy@1d87000` | `UFSDxe` blob | OK |
| vcc | `pm8350_l7`, max `1100000` µA | `EnableUfsIOC = 1` | OK |
| vccq | `pm8350_l9`, max `1200000` µA | `UfsSmmuConfigForOtherBootDev = 1` | OK |
| reset-gpio (TLMM 210) | intentionally omitted in mainline | n/a | OK |

- Both UFS config knobs in `ConfigurationMapLib.c` match stock `uefiplat.cfg`.
  `UFSDxe` is wired in `Include/DXE.inc`. No change needed.

## PMIC / SPMI

| Item | Mainline (pinned) | UEFI | Verdict |
|------|-------------------|------|---------|
| SPMI arbiter | `spmi@c400000` | `SPMIDxe` blob | OK |
| PMICs | pm8350, pm8350b, pm8350c, pm8450, pmk8350, pmr735a | `PmicDxeLa` + `RpmhDxe` blobs | OK |
| IMEM / cookies | `0x146aa000` (`SharedIMEMBaseAddr`) | `{"SharedIMEMBaseAddr", 0x146AA000}` | OK |
| PIL debug cookie | `0x146aa6dc` | `{"PilSubsysDbgCookieAddr", 0x146AA6DC}` | OK |

- PMIC base addresses are not encoded in the device package; they are consumed by the
  prebuilt `PmicDxe`/`SPMIDxe`/`RpmhDxe` binaries. The values that *are* configurable
  (`SharedIMEMBaseAddr`, `PilSubsysDbgCookie*`, `SecurityFlag`, `NumCpus`, …) match the
  stock `uefiplat.cfg` bit-for-bit.

## Memory map notes

- `MemoryMapLib.c` was aligned with stock:
  - `PIL Reserved` length `0x1C200000` → **`0x1DC00000`**.
    This is corroborated by stock `Binaries/marble/RawFiles/uefipil.cfg`:
    `[FULL_ADSP] ResvMemoryStart = 0x9FD00000`, `ResvMemorySize = 0x3100000`
    → ends at `0xA2E00000`, which is exactly `0x85200000 + 0x1DC00000`.
    Mainline `adsp_mem: memory@9fd00000 { reg = <... 0x3100000>; }` matches.
  - `CPU Vectors` (stock `0xA7600000/0x1000`) stays removed (recent Qcom cleanup).
  - UEFI FD stays split: `FD Reserved 0xA7000000/0x100000` + `UEFI FD 0xA7100000/0x300000`,
    matching `Resources/Configs/marble.toml` (`base = 0xA7100000`, `size = 0x300000`)
    and the BootShim layout. A comment was added in `MemoryMapLib.c` explaining why the
    split differs from stock's single 4 MiB `UEFI FD` at `0xA7000000`.
  - `Display Reserved 0xB8000000/0x02B00000` unchanged.
- Observation (stock quirk, no action taken): stock `Display Demura` is
  `0xA1400000/0x02B00000`, i.e. it overlaps `PIL Reserved` (`0x85200000..0xA2E00000`)
  by `0x1A00000` in the stock configuration itself. The previous Mu length
  `0x1C200000` ended exactly at `0xA1400000` (no overlap), so the old value hid the
  conflict. The director explicitly requested stock alignment, so the stock value is
  used; the overlap is inherent to the stock `uefiplat.cfg` and affects both firmwares
  equally. If real-device instability appears around `0xA1400000..0xA2E00000`, this is
  the first place to look.

## Config parameters (`ConfigurationMapLib.c` vs stock `uefiplat.cfg`)

All numeric entries match the stock `[ConfigParameters]`. The only stock keys not
present in source are metadata that Mu handles elsewhere:

- `ConfigParameterCount`, `PlatConfigFileName`, `OsTypeString` (parser metadata)
- `SpecialLogPartition = "LOGFS:\"` (partition default)
- `DefaultChargerApp = "QcomChargerApp"`, `DefaultBDSBootApp = "LinuxLoader"`
  (BDS defaults; no device package in the tree sets these in `ConfigurationMapLib.c`,
  so this was left as-is — see remaining gaps).

## Verdict

- One functional fix: `PIL Reserved` length aligned with stock (step 2).
- One documentation/robustness fix: `build-marble-dtb.sh` now pins the DTS to the
  commit in `FdtBlob/Source.txt` instead of the dirty working tree.
- Display, keys, UFS and PMIC all agree with the pinned mainline DTS and stock
  configuration; no further device-package changes were required.
