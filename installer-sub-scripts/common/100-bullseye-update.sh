# ------------------------------------------------------------------------------
# BULLSEYE_UPDATE.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="eb-bullseye"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$BULLSEYE_SKIPPED" != true ]] && exit
[[ "$DONT_RUN_BULLSEYE_UPDATE" = true ]] && exit

echo
echo "---------------------- $MACH UPDATE -----------------------"

# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
lxc-attach -n $MACH -- ping -c1 deb.debian.org || sleep 3

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
# update
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive

for i in 1 2 3; do
    sleep 1
    apt-get -y --allow-releaseinfo-change update && sleep 3 && break
done

apt-get $APT_PROXY_OPTION -y dist-upgrade
EOS

# ------------------------------------------------------------------------------
# TIMEZONE
# ------------------------------------------------------------------------------
lxc-attach -n $MACH -- zsh <<EOS
set -e
echo $TIMEZONE > /etc/timezone
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/$TIMEZONE /etc/localtime
EOS

# ------------------------------------------------------------------------------
# CONTAINER SERVICES
# ------------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
