#!/bin/bash

# ------------------------------------------------------------------------------
# HOST_CUSTOM.SH
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
[[ "$DONT_RUN_HOST_CUSTOM" = true ]] && exit

echo
echo "---------------------- HOST CUSTOM ------------------------"

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# upgrade
apt-get $APT_PROXY_OPTION -yd dist-upgrade
apt-get $APT_PROXY_OPTION -y upgrade

# added packages
apt-get $APT_PROXY_OPTION -y install zsh tmux vim autojump
apt-get $APT_PROXY_OPTION -y install htop iotop bmon bwm-ng
apt-get $APT_PROXY_OPTION -y install fping whois
apt-get $APT_PROXY_OPTION -y install net-tools ngrep ncat
apt-get $APT_PROXY_OPTION -y install wget curl rsync
apt-get $APT_PROXY_OPTION -y install bzip2 ack jq
apt-get $APT_PROXY_OPTION -y install rsyslog

# ------------------------------------------------------------------------------
# ROOT USER
# ------------------------------------------------------------------------------
# rc files
[[ ! -f "/root/.bashrc" ]] && cp root/.bashrc /root/ || true
[[ ! -f "/root/.vimrc" ]] && cp root/.vimrc /root/ || true
[[ ! -f "/root/.zshrc" ]] && cp root/.zshrc /root/ || true
[[ ! -f "/root/.tmux.conf" ]] && cp root/.tmux.conf /root/ || true
