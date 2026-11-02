#!/system/bin/sh
# This SukiSU build delegates module system/ mounting to a metamodule and none
# is installed, so the file is bind-mounted here instead of relying on overlay.
MODDIR=${0%/*}
SRC="$MODDIR/system/etc/vintf/manifest.xml"
DST="/system/etc/vintf/manifest.xml"
LOG="$MODDIR/last_run.log"
{
  echo "[$(date '+%F %T')] post-fs-data start"
  if grep -q '<vendor-ndk>' "$DST" 2>/dev/null; then
    echo "already patched, skip bind"
  elif mount -o bind "$SRC" "$DST"; then
    echo "bind ok, vendor-ndk tags visible: $(grep -c vendor-ndk "$DST")"
  else
    echo "bind FAILED rc=$?"
  fi
} > "$LOG" 2>&1
