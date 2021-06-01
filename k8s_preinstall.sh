#!/bin/bash

# Check I'm root
if [[ "$(whoami)" != "root" ]]
then
	echo "Must be root but was $(whoami)";
#	exit;
fi

# Add to /etc/hosts
if ! grep -q "192.168.122.2" /etc/hosts
then
	echo "# Added by k8s installer" >> /etc/hosts
	echo "192.168.122.2	n2" >> /etc/hosts
	echo "192.168.122.3	n3" >> /etc/hosts
	echo "192.168.122.4	n4" >> /etc/hosts
fi

# Delete swap file in /etc/fstab
sed -i '/swap/d' /etc/fstab

# Load br_netfiltr
if ! lsmod | grep -q br_netfilter
then
echo "br_netfilter not found. Configuring in /etc/modules-load.d/k8s.conf"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

# Apply
modprobe br_netfilter
fi

if ! sysctl net.bridge.bridge-nf-call-ip6tables | grep -q "= 1"
then
echo "Enabling iptables to see bridged traffic"
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# Apply
sysctl --system
fi
