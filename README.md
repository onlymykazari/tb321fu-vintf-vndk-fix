# tb321fu-vintf-vndk-fix

**English** | [简体中文](README.zh-CN.md)

KernelSU / SukiSU module that removes the boot-time dialog *"There's an internal problem with your device. Contact your manufacturer for details"* on the Lenovo Legion Y700 (2025) / Legion Tab Gen 3 (**TB321FU**) running the [PixelOS 15 Tangorpro GSI](https://github.com/CharlesGool/TB321FU_PixelOS_15_Tangorpro) on top of the ZUI 17.5.10.170 vendor.

## Root cause

The dialog is raised by AOSP's [`Build.isBuildConsistent()`](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/os/Build.java). On Treble devices that method only runs `VintfObject.verifyBuildAtBoot()` (the VINTF compatibility check); when it fails, ActivityTaskManager logs `Build fingerprint is not consistent, warning user` and shows the dialog. AVB/vbmeta is not part of this check, and the system/vendor fingerprint comparison is never reached, so the usual "disable vbmeta verification" / "spoof fingerprint" advice does nothing here.

Running the on-device `vintf legacy` tool shows exactly one failing item:

```
Framework HAL Manifest <==> Device Compatibility Matrix? INCOMPATIBLE,
Vndk version 34 is not supported. Supported versions in framework manifest are: []
```

The ZUI 17.5 vendor is frozen at Android 14 (`ro.vndk.version=34`) and its device compatibility matrix requires the framework to declare `vendor-ndk 34`. The GSI's `/system/etc/vintf/manifest.xml` declares no `<vendor-ndk>` at all: Pixel's own Android 15 vendor no longer needs VNDK, and the port missed this piece of metadata. The GSI does ship `com.android.vndk.v30`–`v34` APEXes, all active and used by the linker, so adding the declaration states the truth rather than bypassing the check.

## What it does

- [`system/etc/vintf/manifest.xml`](system/etc/vintf/manifest.xml): the device's original manifest ([`original/manifest.xml`](original/manifest.xml)) plus five `<vendor-ndk>` blocks (30–34); everything else is byte-identical (the diff is exactly 15 added lines).
- [`post-fs-data.sh`](post-fs-data.sh): bind-mounts that file over `/system/etc/vintf/manifest.xml` early in boot and records the result in `last_run.log` inside the module directory.

Why a bind mount instead of the module's `system/` overlay: SukiSU Ultra (ksud 4.1.2) delegates mounting of module `system/` trees to a *metamodule*; with none installed the step is silently skipped even though the manager shows the module as enabled. The bind mount needs no metamodule, and a mount made in the init namespace propagates to zygote and system_server.

## Install

1. Download `vintf_vndk_fix.zip` from [Releases](../../releases).
2. SukiSU / KernelSU manager → Modules → Install from storage → reboot, or from a root shell: `ksud module install vintf_vndk_fix.zip`.

## Verify

No root needed:

```
adb shell vintf legacy | tail -4
```

All four lines should read `GOOD`. With root you can also check `/data/adb/modules/vintf_vndk_fix/last_run.log` (`bind ok, vendor-ndk tags visible: 10`) and confirm that this boot's `/data/adb/ksu/log/logcat.log` no longer contains `Vendor interface is incompatible`.

## Notes

- The whole file is replaced. **Uninstall before flashing a different GSI build**, whose manifest may contain new entries. The proper fix is for the GSI to declare `vendor-ndk` at build time.
- Verified only on TB321FU + the GSI above (V6) + ZUI 17.5.10.170 vendor. If `vintf legacy` on another device/ROM reports the same `Vndk version N is not supported`, replace `manifest.xml` with that device's original manifest plus the matching `<vendor-ndk>` block.

## Rebuild

```
python3 build.py
```

## License

MIT
