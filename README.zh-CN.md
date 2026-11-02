# tb321fu-vintf-vndk-fix

[English](README.md) | **简体中文**

KernelSU / SukiSU 模块：消除联想拯救者 Y700 三代 / Legion Tab Gen 3（**TB321FU**）刷入 [PixelOS 15 Tangorpro GSI](https://github.com/CharlesGool/TB321FU_PixelOS_15_Tangorpro)（底包 ZUI 17.5.10.170）后，每次开机弹出的「安卓系统内部出现问题，请联系设备制造商」（*There's an internal problem with your device. Contact your manufacturer for details*）。

## 根因

弹窗来自 AOSP 的 [`Build.isBuildConsistent()`](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/os/Build.java)。在 Treble 设备上它只做一件事——`VintfObject.verifyBuildAtBoot()`，即 VINTF 兼容性校验；不通过时 ActivityTaskManager 记录 `Build fingerprint is not consistent, warning user` 并弹窗。它**不检查 AVB/vbmeta**，也**走不到** system/vendor 指纹比对，所以网上常见的“关 vbmeta 校验”“对齐指纹”都不起作用。

用系统自带的 `vintf legacy` 复现，只有一项不通过：

```
Framework HAL Manifest <==> Device Compatibility Matrix? INCOMPATIBLE,
Vndk version 34 is not supported. Supported versions in framework manifest are: []
```

ZUI 17.5 的 vendor 冻结在 Android 14（`ro.vndk.version=34`），它的设备兼容矩阵只要求框架声明 `vendor-ndk 34`；而这个 GSI 的 `/system/etc/vintf/manifest.xml` 没有任何 `<vendor-ndk>` 块——Android 15 起 Pixel 自家 vendor 不再需要 VNDK，移植时漏掉了这段元数据。GSI 实际上带着 `com.android.vndk.v30`～`v34` 五个 APEX 且全部激活、linker 也在用，所以补上声明是如实修正，不是绕过校验。

## 做了什么

- [`system/etc/vintf/manifest.xml`](system/etc/vintf/manifest.xml)：设备上的原始清单（[`original/manifest.xml`](original/manifest.xml)）加上 5 个 `<vendor-ndk>` 块（30–34），其余逐字节相同，`diff` 正好 15 行。
- [`post-fs-data.sh`](post-fs-data.sh)：开机早期把它 `mount -o bind` 到 `/system/etc/vintf/manifest.xml`，结果写到模块目录的 `last_run.log`。

为什么不用模块的 `system/` 目录覆盖：SukiSU Ultra（ksud 4.1.2）把模块 `system/` 的挂载交给了“元模块（metamodule）”，没装元模块时**静默跳过**，管理器里显示“已启用”也不会挂载。bind mount 不依赖元模块；在 init 命名空间里挂上后会传播到 zygote / system_server。

## 安装

1. 从 [Releases](../../releases) 下载 `vintf_vndk_fix.zip`。
2. SukiSU / KernelSU 管理器 → 模块 → 从本地安装 → 重启；或在 root shell 里 `ksud module install vintf_vndk_fix.zip`。

## 验证

不需要 root：

```
adb shell vintf legacy | tail -4
```

四行应全部为 `GOOD`。有 root 的话还可以看 `/data/adb/modules/vintf_vndk_fix/last_run.log`（应为 `bind ok, vendor-ndk tags visible: 10`），以及本次开机的 `/data/adb/ksu/log/logcat.log` 里不再有 `Vendor interface is incompatible`。

## 注意

- 这是整文件覆盖。**换 GSI 版本前先卸载**，新版本的清单可能有新增条目。更根本的修法是 GSI 构建时声明 `vendor-ndk`。
- 只在 TB321FU + 上述 GSI V6 + ZUI 17.5.10.170 vendor 上验证过。其他机型/ROM 如果 `vintf legacy` 报的是同样的 `Vndk version N is not supported`，把 `manifest.xml` 换成你机器上的原始清单并加上对应版本的 `<vendor-ndk>` 块即可。

## 重新打包

```
python3 build.py
```

## 许可证

MIT
