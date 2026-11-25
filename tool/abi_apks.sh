#!/usr/bin/env bash
# (25-11-2026, Shorebird) THE FILE PER PROCESSOR (3.19.1 – a phone's update downloads only its own), made FROM the one app file
# Shorebird built. Shorebird makes one release per version (it refuses --split-per-abi, and a second build of the same version), and a
# phone takes a patch only when its app is the very one Shorebird released – so the per-processor files are no longer built again: the
# other processor's folder (lib/<abi>/) is taken out of Shorebird's file – what RCL_ABIS left out before – then it is aligned and
# signed again with the app's own key. Checked here: signed, aligned, only its own processor, and every other entry byte for byte the
# one of Shorebird's file (so the patches fit).
#   bash tool/abi_apks.sh <shorebird's apk> <version> <build>   → rcl-erp-<version>-<build>.arm64-v8a.apk / .armeabi-v7a.apk
#   needs android/key.properties + the keystore (the release's "Signing key" step) and $ANDROID_HOME
set -euo pipefail
U="$1"; VER="$2"; BN="$3"
AS=$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -1)
KP=android/key.properties
[ -f "$KP" ] || { echo "::error::android/key.properties is missing – the per-processor files cannot be signed."; exit 1; }
prop() { grep "^$1=" "$KP" | head -1 | cut -d= -f2-; }
SF="android/$(prop storeFile)"; KA=$(prop keyAlias)
KS_PASS=$(prop storePassword); KEY_PASS=$(prop keyPassword); export KS_PASS KEY_PASS
echo "::add-mask::$KS_PASS"; echo "::add-mask::$KEY_PASS"
W=$(mktemp -d)
for abi in arm64-v8a armeabi-v7a; do
  out="rcl-erp-$VER-$BN.$abi.apk"
  cp "$U" "$W/in.apk"
  others=$(unzip -Z1 "$U" | grep '^lib/' | cut -d/ -f2 | sort -u | grep -vx "$abi" || true)
  [ -n "$(unzip -Z1 "$U" | grep "^lib/$abi/" || true)" ] || { echo "::error::$U has no lib/$abi/."; exit 1; }
  for o in $others; do zip -q -d "$W/in.apk" "lib/$o/*"; done
  zip -q -d "$W/in.apk" 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.EC' 'META-INF/*.DSA' 'META-INF/MANIFEST.MF' >/dev/null 2>&1 || true
  rm -f "$W/aligned.apk"
  if "${AS}zipalign" -P 16 -f 4 "$W/in.apk" "$W/aligned.apk" 2>/dev/null; then AL="-P 16"; else "${AS}zipalign" -p -f 4 "$W/in.apk" "$W/aligned.apk"; AL="-p"; fi
  "${AS}apksigner" sign --ks "$SF" --ks-key-alias "$KA" --ks-pass env:KS_PASS --key-pass env:KEY_PASS --out "$out" "$W/aligned.apk"
  "${AS}zipalign" -c $AL 4 "$out" >/dev/null || { echo "::error::$out is not aligned."; exit 1; }
  "${AS}apksigner" verify "$out" >/dev/null || { echo "::error::$out: the signature does not verify."; exit 1; }
  left=$(unzip -Z1 "$out" | grep '^lib/' | cut -d/ -f2 | sort -u | grep -vx "$abi" || true)
  [ -z "$left" ] || { echo "::error::$out also has the parts of: $left"; exit 1; }
  python3 - "$U" "$out" "$abi" <<'PY'
import sys, zipfile, re
u, o, abi = sys.argv[1:4]
sig = re.compile(r'^META-INF/([^/]+\.(SF|RSA|EC|DSA)|MANIFEST\.MF)$')
A = {i.filename: (i.CRC, i.file_size) for i in zipfile.ZipFile(u).infolist() if not sig.match(i.filename)}
B = {i.filename: (i.CRC, i.file_size) for i in zipfile.ZipFile(o).infolist() if not sig.match(i.filename)}
want = {k: v for k, v in A.items() if not k.startswith('lib/') or k.startswith('lib/%s/' % abi)}
miss = sorted(set(want) - set(B)); extra = sorted(set(B) - set(want)); diff = sorted(k for k in want if k in B and want[k] != B[k])
if miss or extra or diff:
    print('::error::%s is not Shorebird\'s file less the other processor – missing %s, extra %s, changed %s' % (o, miss[:5], extra[:5], diff[:5])); sys.exit(1)
print('::notice::%s: %d entries, each byte for byte Shorebird\'s (lib/%s/ kept)' % (o, len(B), abi))
PY
done
rm -rf "$W"
