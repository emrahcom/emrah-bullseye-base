#!/bin/bash

# ------------------------------------------------------------------------------
# NETWORK.SH
# ------------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------
MACH="eb-host"
cd $MACHINES/$MACH

# public interface
DEFAULT_ROUTE=$(ip route | egrep '^default ' | head -n1)
PUBLIC_INTERFACE=${DEFAULT_ROUTE##*dev }
PUBLIC_INTERFACE=${PUBLIC_INTERFACE/% */}
echo PUBLIC_INTERFACE="$PUBLIC_INTERFACE" >> $INSTALLER/000-source

# IP address
DNS_RECORD=$(grep 'address=/host/' etc/dnsmasq.d/eb-hosts | head -n1)
IP=${DNS_RECORD##*/}
echo HOST="$IP" >> $INSTALLER/000-source

# remote IP address (local IP for remote connections)
REMOTE_IP=$(ip addr show $PUBLIC_INTERFACE | ack "$PUBLIC_INTERFACE$" | \
            xargs | cut -d " " -f2 | cut -d "/" -f1)
echo REMOTE_IP="$REMOTE_IP" >> $INSTALLER/000-source

# external IP (Internet IP)
EXTERNAL_IP=$(dig -4 +short myip.opendns.com a @resolver1.opendns.com) || true
echo EXTERNAL_IP="$EXTERNAL_IP" >> $INSTALLER/000-source

# ------------------------------------------------------------------------------
# INIT
# ------------------------------------------------------------------------------
[[ "$DONT_RUN_NETWORK_INIT" = true ]] && exit

echo
echo "------------------------ NETWORK --------------------------"

# ------------------------------------------------------------------------------
# BACKUP & STATUS
# ------------------------------------------------------------------------------
OLD_FILES="/root/eb-old-files/$DATE"
mkdir -p $OLD_FILES

# backup the files which will be changed
[[ -f /etc/nftables.conf ]] && cp /etc/nftables.conf $OLD_FILES/
[[ -f /etc/network/interfaces ]] && cp /etc/network/interfaces $OLD_FILES/
[[ -f /etc/dnsmasq.d/eb-hosts ]] && cp /etc/dnsmasq.d/eb-hosts $OLD_FILES/
[[ -f /etc/default/dnsmasq ]] && cp /etc/default/dnsmasq $OLD_FILES/
[[ -f /etc/default/lxc-net ]] && cp /etc/default/lxc-net $OLD_FILES/

# network status
echo "# ----- ip addr -----" >> $OLD_FILES/network.status
ip addr >> $OLD_FILES/network.status
echo >> $OLD_FILES/network.status
echo "# ----- ip route -----" >> $OLD_FILES/network.status
ip route >> $OLD_FILES/network.status

# nftables status
if [[ "$(systemctl is-active nftables.service)" = "active" ]]; then
    echo "# ----- nft list ruleset -----" >> $OLD_FILES/nftables.status
    nft list ruleset >> $OLD_FILES/nftables.status
fi

# ------------------------------------------------------------------------------
# PACKAGES
# ------------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

# added packages
apt-get $APT_PROXY -y install nftables

# ------------------------------------------------------------------------------
# NETWORK CONFIG
# ------------------------------------------------------------------------------
# changed/added system files
cp etc/dnsmasq.d/eb-hosts /etc/dnsmasq.d/
cp etc/dnsmasq.d/eb-resolv /etc/dnsmasq.d/
[[ -z "$(egrep '^DNSMASQ_EXCEPT' /etc/default/dnsmasq)" ]] && \
    sed -i "s/^#DNSMASQ_EXCEPT/DNSMASQ_EXCEPT/" /etc/default/dnsmasq

# /etc/network/interfaces
[[ -z "$(egrep '^source-directory\s*interfaces.d' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source-directory\s*/etc/network/interfaces.d' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source\s*interfaces.d/\*$' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source\s*/etc/network/interfaces.d/\*$' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source\s*interfaces.d/\*\.cfg' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source\s*/etc/network/interfaces.d/\*\.cfg' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source\s*interfaces.d/eb-bridge.cfg' /etc/network/interfaces || true)" ]] && \
[[ -z "$(egrep '^source\s*/etc/network/interfaces.d/eb-bridge.cfg' /etc/network/interfaces || true)" ]] && \
echo -e "\nsource /etc/network/interfaces.d/eb-bridge.cfg" >> /etc/network/interfaces

# /etc/network/cloud-interfaces-template
if [[ -f "/etc/network/cloud-interfaces-template" ]]; then
    [[ -z "$(egrep '^source-directory\s*interfaces.d' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source-directory\s*/etc/network/interfaces.d' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source\s*interfaces.d/\*$' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source\s*/etc/network/interfaces.d/\*$' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source\s*interfaces.d/\*\.cfg' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source\s*/etc/network/interfaces.d/\*\.cfg' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source\s*interfaces.d/eb-bridge.cfg' /etc/network/cloud-interfaces-template || true)" ]] && \
    [[ -z "$(egrep '^source\s*/etc/network/interfaces.d/eb-bridge.cfg' /etc/network/cloud-interfaces-template || true)" ]] && \
    echo -e "\nsource /etc/network/interfaces.d/eb-bridge.cfg" >> /etc/network/cloud-interfaces-template
fi

# IP forwarding
cp etc/sysctl.d/eb-ip-forward.conf /etc/sysctl.d/
sysctl -p /etc/sysctl.d/eb-ip-forward.conf || true
[[ "$(cat /proc/sys/net/ipv4/ip_forward)" != 1 ]] && false

# ------------------------------------------------------------------------------
# LXC-NET
# ------------------------------------------------------------------------------
cp etc/default/lxc-net /etc/default/
systemctl restart lxc-net.service

# ------------------------------------------------------------------------------
# DUMMY INTERFACE & BRIDGE
# ------------------------------------------------------------------------------
# the random MAC address for the dummy interface
MAC_ADDRESS=$(date +'52:54:%d:%H:%M:%S')

cp etc/network/interfaces.d/eb-bridge.cfg /etc/network/interfaces.d/
sed -i "s/___MAC_ADDRESS___/${MAC_ADDRESS}/g" \
    /etc/network/interfaces.d/eb-bridge.cfg
sed -i "s/___BRIDGE___/${BRIDGE}/g" /etc/network/interfaces.d/eb-bridge.cfg
cp etc/dnsmasq.d/eb-interface /etc/dnsmasq.d/
sed -i "s/___BRIDGE___/${BRIDGE}/g" /etc/dnsmasq.d/eb-interface

ifup -i /etc/network/interfaces.d/eb-bridge.cfg edummy0
ifup -i /etc/network/interfaces.d/eb-bridge.cfg $BRIDGE

# ------------------------------------------------------------------------------
# NFTABLES
# ------------------------------------------------------------------------------
# recreate the custom tables
if [[ "$RECREATE_CUSTOM_NFTABLES" = true ]]; then
    nft delete table inet eb-filter 2>/dev/null || true
    nft delete table ip eb-nat 2>/dev/null || true
fi

# table: eb-filter
# chains: input, forward, output
# rules: drop from the public interface to the private internal network
nft add table inet eb-filter
nft add chain inet eb-filter \
    input { type filter hook input priority 0 \; }
nft add chain inet eb-filter \
    forward { type filter hook forward priority 0 \; }
nft add chain inet eb-filter \
    output { type filter hook output priority 0 \; }
[[ -z "$(nft list chain inet eb-filter output | \
ack 'ip daddr 172.22.22.0/24 drop')" ]] && \
    nft add rule inet eb-filter output \
    iif $PUBLIC_INTERFACE ip daddr 172.22.22.0/24 drop

# table: eb-nat
# chains: prerouting, postrouting, output, input
# rules: masquerade
nft add table ip eb-nat
nft add chain ip eb-nat prerouting \
    { type nat hook prerouting priority 0 \; }
nft add chain ip eb-nat postrouting \
    { type nat hook postrouting priority 100 \; }
nft add chain ip eb-nat output \
    { type nat hook output priority 0 \; }
nft add chain ip eb-nat input \
    { type nat hook input priority 0 \; }
[[ -z "$(nft list chain ip eb-nat postrouting | \
ack 'ip saddr 172.22.22.0/24 masquerade')" ]] && \
    nft add rule ip eb-nat postrouting \
    ip saddr 172.22.22.0/24 masquerade

# table: eb-nat
# chains: prerouting
# maps: tcp2ip, tcp2port
# rules: tcp dnat
nft add map ip eb-nat tcp2ip \
    { type inet_service : ipv4_addr \; }
nft add map ip eb-nat tcp2port \
    { type inet_service : inet_service \; }
[[ -z "$(nft list chain ip eb-nat prerouting | \
ack 'tcp dport map @tcp2ip:tcp dport map @tcp2port')" ]] && \
    nft add rule ip eb-nat prerouting \
    iif $PUBLIC_INTERFACE dnat \
    tcp dport map @tcp2ip:tcp dport map @tcp2port

# table: eb-nat
# chains: prerouting
# maps: udp2ip, udp2port
# rules: udp dnat
nft add map ip eb-nat udp2ip \
    { type inet_service : ipv4_addr \; }
nft add map ip eb-nat udp2port \
    { type inet_service : inet_service \; }
[[ -z "$(nft list chain ip eb-nat prerouting | \
ack 'udp dport map @udp2ip:udp dport map @udp2port')" ]] && \
    nft add rule ip eb-nat prerouting \
    iif $PUBLIC_INTERFACE dnat \
    udp dport map @udp2ip:udp dport map @udp2port

# ------------------------------------------------------------------------------
# NETWORK RELATED SERVICES
# ------------------------------------------------------------------------------
# dnsmasq
systemctl stop dnsmasq.service
systemctl start dnsmasq.service

# nftables
systemctl enable nftables.service

# ------------------------------------------------------------------------------
# STATUS
# ------------------------------------------------------------------------------
ip addr
