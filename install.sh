#!/bin/bash
# Install the CS4208 speaker driver for MacBook9,1 via DKMS.
# Run in a real terminal (sudo needs to prompt for a password).
set -euo pipefail

REPO=https://github.com/juicecultus/macbook12-audio-driver.git
COMMIT=75884e2
DIR="$HOME/macbook12-audio-driver"   # DKMS rebuilds from here; don't delete it

sudo apt install -y dkms gcc make wget git "linux-headers-$(uname -r)"

if [[ ! -d $DIR ]]; then
    git clone "$REPO" "$DIR"
fi
git -C "$DIR" fetch -q origin
git -C "$DIR" checkout -q "$COMMIT"

cd "$DIR"
sudo ./install.cirrus.driver.sh -i

echo
echo "Installed. Reboot to load the new module:"
echo "  GNOME power menu -> Restart, or: sudo systemctl reboot -i"
echo "Afterwards run ./verify.sh"
