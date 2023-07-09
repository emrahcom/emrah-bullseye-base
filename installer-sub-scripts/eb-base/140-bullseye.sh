# ------------------------------------------------------------------------------
# BULLSEYE.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="$TAG-bullseye"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_BULLSEYE" = true ]] && exit

echo
echo "-------------------------- $MACH --------------------------"

# ------------------------------------------------------------------------------
# REINSTALL_IF_EXISTS
# ------------------------------------------------------------------------------
EXISTS=$(lxc-info -n $MACH | egrep '^State' || true)
if [[ -n "$EXISTS" ]] && [[ "$REINSTALL_BULLSEYE_IF_EXISTS" != true ]]; then
    echo BULLSEYE_SKIPPED=true >> $INSTALLER/000-source

    echo "Already installed. Skipped..."
    echo
    echo "Please set REINSTALL_BULLSEYE_IF_EXISTS in $APP_CONFIG"
    echo "if you want to reinstall this container"
    exit
fi

# ------------------------------------------------------------------------------
# CONTAINER SETUP
# ------------------------------------------------------------------------------
# remove the old container if exists
set +e
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-destroy -n $MACH
rm -rf /var/lib/lxc/$MACH
sleep 1
set -e

# clear LXC templates cache to get the newest one
rm -rf /var/cache/lxc/download/debian/bullseye/$ARCH/default

# create the new one
lxc-create -n $MACH -t download -P /var/lib/lxc/ -- \
    -d debian -r bullseye -a $ARCH

# shared directories
mkdir -p $SHARED/cache
cp -arp $MACHINE_HOST/usr/local/$TAG/cache/bullseye-apt-archives $SHARED/cache/

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
sed -i '/^lxc\.net\./d' /var/lib/lxc/$MACH/config
sed -i '/^# Network configuration/d' /var/lib/lxc/$MACH/config
sed -i 's/^lxc.apparmor.profile.*$/lxc.apparmor.profile = unconfined/' \
    /var/lib/lxc/$MACH/config

cat >> /var/lib/lxc/$MACH/config <<EOF
# Network configuration
lxc.net.0.type = veth
lxc.net.0.link = $BRIDGE
lxc.net.0.name = eth0
lxc.net.0.flags = up

lxc.mount.entry = $SHARED/cache/bullseye-apt-archives \
var/cache/apt/archives none bind 0 0
EOF

# changed/added system files
echo "DNS=$HOST" >> $ROOTFS/etc/systemd/resolved.conf
cp etc/apt/sources.list $ROOTFS/etc/apt/
cp etc/apt/apt.conf.d/80disable-recommends $ROOTFS/etc/apt/apt.conf.d/

# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
sleep 1

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
# ca-certificates for https repo
apt-get $APT_PROXY \
    -o dir::cache::archives="/usr/local/$TAG/cache/bullseye-apt-archives/" \
    -dy reinstall iputils-ping ca-certificates openssl

lxc-attach -n $MACH -- bash <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
dpkg -i \$(ls -1t /var/cache/apt/archives/openssl_* | head -1)
dpkg -i \$(ls -1t /var/cache/apt/archives/ca-certificates_* | head -1)
dpkg -i \$(ls -1t /var/cache/apt/archives/iputils-ping_* | head -1)
EOS

# wait for the network to be up
for i in $(seq 0 9); do
    lxc-attach -n $MACH -- ping -c1 host.loc && break || true
    sleep 1
done

# update
lxc-attach -n $MACH -- bash <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get -y --allow-releaseinfo-change update
apt-get $APT_PROXY -y dist-upgrade
EOS

# packages
lxc-attach -n $MACH -- bash <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -y install apt-utils
apt-get $APT_PROXY -y install zsh
EOS

lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY -y install openssh-server openssh-client
apt-get $APT_PROXY -y install cron logrotate
apt-get $APT_PROXY -y install dbus libpam-systemd
apt-get $APT_PROXY -y install wget
EOS

# ------------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# ------------------------------------------------------------------------------
# tzdata
lxc-attach -n $MACH -- zsh <<EOS
set -e
echo $TIMEZONE > /etc/timezone
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/$TIMEZONE /etc/localtime
EOS

# ssh
cp etc/ssh/sshd_config.d/$TAG.conf $ROOTFS/etc/ssh/sshd_config.d/

# ------------------------------------------------------------------------------
# ROOT USER
# ------------------------------------------------------------------------------
# ssh
if [[ -f /root/.ssh/authorized_keys ]]; then
    mkdir -p $ROOTFS/root/.ssh
    cp /root/.ssh/authorized_keys $ROOTFS/root/.ssh/
    chmod 700 $ROOTFS/root/.ssh
    chmod 600 $ROOTFS/root/.ssh/authorized_keys
fi

# ------------------------------------------------------------------------------
# CONTAINER SERVICES
# ------------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
