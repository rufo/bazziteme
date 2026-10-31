#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1
#
# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

# Install IVPN as the current VPN of choice
curl -fsSL https://repo.ivpn.net/stable/fedora/generic/ivpn.repo > /etc/yum.repos.d/ivpn.repo
dnf5 config-manager setopt ivpn-stable.enabled=0
dnf5 install --enable-repo="ivpn-stable" -y ivpn ivpn-ui

# Install keyd from its copr for remapping
dnf5 -y copr enable alternateved/keyd
dnf5 -y install keyd
dnf5 -y copr disable alternateved/keyd

# For the Copyous shell extension
dnf5 -y install libgda libgda-sqlite

# Remove pre-installed VS Code, we'll use the ublue-os/tap version
dnf5 remove -y code || true
rm -f /etc/yum.repos.d/vscode.repo

# Other various packages
dnf5 -y install qt6-qtconnectivity powertop

# from https://github.com/FlyinPancake/1password-flatpak-browser-integration/blob/main/1password-flatpak-browser-integration.sh
#
echo "Adding Flatpak helpers to the list of supported browsers in 1Password"
allowed_browsers=/etc/1password/custom_allowed_browsers
mkdir -p /etc/1password
touch "$allowed_browsers"
for browser in flatpak-session-helper xdg-native-messaging-proxy; do
    if ! grep -Fxq "$browser" "$allowed_browsers"; then
        echo "Adding $browser to allowed browsers"
        printf '%s\n' "$browser" >> "$allowed_browsers"
    fi
done

# Finalizing

# Clean up dnf metadata now that we're done with it
dnf5 clean all

# Clean temporary files
rm -rf /tmp/* || true
