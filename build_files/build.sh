#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

rpm --import https://downloads.1password.com/linux/keys/1password.asc
sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
dnf5 install -y 1password

curl -fsSL https://repo.ivpn.net/stable/fedora/generic/ivpn.repo > /etc/yum.repos.d/ivpn.repo
dnf5 install -y ivpn ivpn-ui

# TODO: look into why we should disable the copr; should we do something after installing the above?
dnf5 -y copr enable alternateved/keyd
dnf5 -y install keyd
dnf5 -y copr disable alternateved/keyd

dnf5 -y install qt6-qtconnectivity

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

# from https://github.com/FlyinPancake/1password-flatpak-browser-integration/blob/main/1password-flatpak-browser-integration.sh
#
echo -e "${INFO}Adding Flatpaks to the list of supported browsers in 1Password${NC}"
if [[ ! -d /etc/1password ]]; then
    echo -e "${INFO}Creating directory /etc/1password${NC}"
    mkdir /etc/1password
fi
if grep -q 'flatpak-session-helper' /etc/1password/custom_allowed_browsers; then
    echo -e "${INFO}Already added to allowed browsers${NC}"
else
    echo -e "${INFO}Adding to allowed browsers${NC}"
    echo -e 'flatpak-session-helper' | tee -a /etc/1password/custom_allowed_browsers >/dev/null
fi
