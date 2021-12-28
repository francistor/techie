#!/bin/bash

############################################################
# This script installs Kubernetes software required in nodes
# in the cluster. To be exectued as the first step
############################################################

# Abort if error
set -e

# Specific version to install
K8S_VERSION=1.21.4-00

echo "[K8S-INSTALL] Installing K8S $K8S_VERSION"

# Check I'm root
if [[ "$(whoami)" != "root" ]]
then
	echo "Must be root but was $(whoami)";
	exit 1;
fi

echo "[K8S-INSTALL] updating & upgrading..."
apt-get update
apt-get upgrade -y
echo "[K8S-INSTALL] done."

# Add to /etc/hosts
if ! grep -q "192.168.122.2" /etc/hosts
then
	echo "# Added by k8s installer" >> /etc/hosts
	echo "192.168.122.2	vm2" >> /etc/hosts
	echo "192.168.122.3	vm3" >> /etc/hosts
	echo "192.168.122.4	vm4" >> /etc/hosts
fi

# Delete swap file in /etc/fstab
sed -i '/swap/d' /etc/fstab
swapoff -a

# Load required modules 
echo "[K8S-INSTALL] Applying system configuration..."
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
echo "[K8S-INSTALL] done."

# Install Docker
echo "[K8S-INSTALL] Installing docker..."
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
echo "[K8S-INSTALL] done."

# Enable iSCSI for OpenEBS
echo "[K8S-INSTALL] Enabiling iscsid..."
sudo systemctl enable --now iscsid
echo "[K8S-INSTALL] done"

# Install Kubernetes components
echo "[K8S-INSTALL] Installing Kubernetes..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Use this to check available versions: apt-cache showpkg <package-name>
# To install a specific version apt-get install -y kubelet=1.21.4-00. Use allow-downgrades because some software may be already installed
apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION --allow-downgrades
apt-mark hold kubelet kubeadm kubectl
echo "[K8S-INSTALL] done."

touch $HOME/K8S_Preinstall_Finished

