# ------------------------------------------------------------------------------
# BULLSEYE_CUSTOM.SH
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
[[ "$BULLSEYE_SKIPPED" = true ]] && exit
[[ "$DONT_RUN_BULLSEYE_CUSTOM" = true ]] && exit

echo
echo "---------------------- $MACH CUSTOM -----------------------"

# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
sleep 1

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

# packages
lxc-attach -n $MACH -- zsh <<EOS
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_PROXY_OPTION -y install less tmux vim autojump
apt-get $APT_PROXY_OPTION -y install curl dnsutils
apt-get $APT_PROXY_OPTION -y install net-tools ngrep ncat
apt-get $APT_PROXY_OPTION -y install htop bmon bwm-ng
apt-get $APT_PROXY_OPTION -y install rsync bzip2 man-db ack
EOS

# ------------------------------------------------------------------------------
# ROOT USER
# ------------------------------------------------------------------------------
# shell
lxc-attach -n $MACH -- chsh -s /bin/zsh root
cp root/.bashrc $ROOTFS/root/
cp root/.vimrc $ROOTFS/root/
cp root/.zshrc $ROOTFS/root/
cp root/.tmux.conf $ROOTFS/root/

# ------------------------------------------------------------------------------
# CONTAINER SERVICES
# ------------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
