#!/bin/zsh
# Damage Restoration — remove Gatekeeper quarantine from an ad-hoc MacPower install.
set -euo pipefail

app="/Applications/MacPower.app"

if [[ ! -d "$app" ]]; then
  echo "MacPower.app was not found in /Applications."
  echo "Drag MacPower into Applications first, then run this script again."
  exit 1
fi

echo "This asks for your password to remove the quarantine flag from:"
echo "  $app"
sudo xattr -rd com.apple.quarantine "$app"
echo "Done. Open MacPower from Applications."
