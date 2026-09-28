#!/bin/bash
# Check the patched CS4208 driver is installed and loaded, then play a test tone.

ok()   { echo "  [ok]   $*"; }
fail() { echo "  [FAIL] $*"; failed=1; }
failed=0

echo "Model:  $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
echo "Kernel: $(uname -r)"
echo

if dkms status 2>/dev/null | grep -q "macbook12-audio.*$(uname -r).*installed"; then
    ok "DKMS module installed for $(uname -r)"
else
    fail "DKMS module not installed for $(uname -r) (see: dkms status)"
fi

modfile=$(modinfo -n snd_hda_codec_cs420x 2>/dev/null)
if [[ $modfile == */updates/dkms/* ]]; then
    ok "snd_hda_codec_cs420x resolves to $modfile"
else
    fail "snd_hda_codec_cs420x resolves to stock module: ${modfile:-none}"
fi

if lsmod | grep -q '^snd_hda_codec_cs420x'; then
    ok "snd_hda_codec_cs420x is loaded"
else
    fail "snd_hda_codec_cs420x is not loaded"
fi

if [[ -L /usr/src/macbook12-audio-0.1 && -d /usr/src/macbook12-audio-0.1/ ]]; then
    ok "DKMS source link -> $(readlink /usr/src/macbook12-audio-0.1)"
else
    fail "DKMS source /usr/src/macbook12-audio-0.1 missing or broken"
fi

echo
if [[ $failed -eq 0 && ${1:-} != --no-sound ]]; then
    echo "Playing a 440 Hz tone on the internal speakers..."
    speaker-test -c2 -t sine -f 440 -l1 >/dev/null 2>&1
fi

exit $failed
