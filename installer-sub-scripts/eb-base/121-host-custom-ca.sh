#!/bin/bash

# ------------------------------------------------------------------------------
# HOST_CUSTOM_CA.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-host"
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
if [[ ! -d "/root/$TAG-certs" ]]; then
    mkdir /root/$TAG-certs
    chmod 700 /root/$TAG-certs
fi

if [[ ! -f "/root/$TAG-certs/$TAG-CA.pem" ]]; then
    cd /root/$TAG-certs
    rm -f $TAG-CA.key

    openssl req -nodes -new -x509 -days 10950 \
        -keyout $TAG-CA.key -out $TAG-CA.pem \
        -subj "/O=$TAG/OU=CA/CN=$TAG-bullseye $DATE-$RANDOM"
fi
