#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

# fix /opt
# from https://universal-blue.discourse.group/t/opt-build-error-fix-for-custom-images/10706
rm /opt # this was a symlink file not a directory
mkdir /opt # recreate the opt directory to enable packages to install in it

rpm --import https://downloads.1password.com/linux/keys/1password.asc
sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
dnf5 install -y 1password

curl -fsSL https://repo.ivpn.net/stable/fedora/generic/ivpn.repo > /etc/yum.repos.d/ivpn.repo
dnf5 install -y ivpn ivpn-ui


# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
