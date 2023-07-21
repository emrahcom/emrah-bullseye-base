# ------------------------------------------------------------------------------
# REMINDER.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_REMINDER" = true ]] && exit

echo
echo "------------------------- REMINDER ------------------------"

if [[ "0" = "$SWAP" ]]; then
    cat <<EOF

Add swap file to the host, if there is no swap (mostly on cloud):
>>> dd if=/dev/zero of=/swapfile bs=1M count=2048
>>> chmod 600 /swapfile
>>> mkswap /swapfile
>>> swapon /swapfile
>>> echo '/swapfile none  swap  sw  0  0' >>/etc/fstab
EOF
fi

cat <<EOF

Install the 'open-vm-tools' package to the host if this is a VMware machine:
>>> apt-get install open-vm-tools
EOF
