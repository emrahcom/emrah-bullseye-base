#!/bin/bash

# ------------------------------------------------------------------------------
# HOST_CUSTOM_CA.SH
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
[[ "$DONT_RUN_HOST_CUSTOM_CA" = true ]] && exit

echo
echo "---------------------- HOST CUSTOM CA ---------------------"

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# added packages
apt-get $APT_PROXY -y install openssl

# ------------------------------------------------------------------------------
# CA CERTIFICATE & KEY
# ------------------------------------------------------------------------------
# the CA key and the CA certificate
[[ ! -d "/root/eb-ssl" ]] && mkdir /root/eb-ssl

if [[ ! -f "/root/eb-ssl/eb-CA.pem" ]]; then
    cd /root/eb-ssl
    rm -f eb-CA.key

    openssl req -nodes -new -x509 -days 10950 \
        -keyout eb-CA.key -out eb-CA.pem \
        -subj "/O=emrah-bullseye/OU=CA/CN=emrah-bullseye $DATE-$RANDOM"
fi
