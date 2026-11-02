#!/usr/bin/env python3
"""Pack this directory into vintf_vndk_fix.zip (KernelSU / SukiSU module format)."""
import hashlib
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent
FILES = ["module.prop", "post-fs-data.sh", "system/etc/vintf/manifest.xml"]
OUT = ROOT / "vintf_vndk_fix.zip"

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for rel in FILES:
        z.write(ROOT / rel, rel)

print(f"{OUT.name}  sha256 {hashlib.sha256(OUT.read_bytes()).hexdigest()}")
