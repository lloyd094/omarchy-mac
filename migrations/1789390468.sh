echo "Populate Omarchy Mac signing trust with the new key"

# The updated keyring must arrive through an already trusted transaction before
# activating the replacement signer. This migration does not change repo policy.
if omarchy-pkg-missing omarchy-mac-keyring; then
  echo "Install the reviewed Omarchy Mac keyring transition before activating the replacement signer." >&2
  return 1
fi

sudo pacman-key --populate omarchy-mac
for omarchy_mac_signing_key in \
  FBD6874D423C418DDB6D143EECE19CDDE306DBD2; do
  sudo pacman-key --finger "$omarchy_mac_signing_key" | tr -d '[:space:]' | grep -qF "$omarchy_mac_signing_key"
done
