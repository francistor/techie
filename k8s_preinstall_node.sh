#!/bin/bash

# Check I'm root
if [[ "$(whoami)" != "root" ]]
then
	echo "Must be root but was $(whoami)";
	exit;
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

# Load required modules 

cat <<EOF > /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF

# Apply
modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply
sysctl --system

# Install Docker
apt-get install -y docker.io
systemctl enable docker.service

# Setup Docker with systemd as cgroups manager
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

# Install Kubernetes components
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

