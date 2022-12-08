#!/bin/bash

# ------------------------------------------------------------------------------
# HOST.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="eb-host"
cd $MACHINES/$MACH

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_HOST" = true ]] && exit

echo
echo "-------------------------- HOST ---------------------------"

# ------------------------------------------------------------------------------
# BACKUP & STATUS
# ------------------------------------------------------------------------------
OLD_FILES="/root/eb-old-files/$DATE"
mkdir -p $OLD_FILES

# process status
echo "# ----- ps auxfw -----" >> $OLD_FILES/ps.status
ps auxfw >> $OLD_FILES/ps.status

# deb status
echo "# ----- dpkg -l -----" >> $OLD_FILES/dpkg.status
dpkg -l >> $OLD_FILES/dpkg.status

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# load the bridge module before the possible kernel update
[[ -n "$(command -v modprobe)" ]] && [[ -z "$(lsmod | grep bridge)" ]] && \
    modprobe bridge
# load the veth module before the possible kernel update
[[ -n "$(command -v modprobe)" ]] && [[ -z "$(lsmod | grep veth)" ]] && \
    modprobe veth

# upgrade
apt-get $APT_PROXY -yd dist-upgrade
apt-get $APT_PROXY -y upgrade
apt-get $APT_PROXY -y install apt-utils

# added packages
apt-get $APT_PROXY -y install lxc debootstrap bridge-utils
apt-get $APT_PROXY -y install dnsmasq dnsutils
apt-get $APT_PROXY -y install xz-utils gnupg pwgen
apt-get $APT_PROXY -y install wget ca-certificates
apt-get $APT_PROXY -y install iputils-ping
