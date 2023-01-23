#!/bin/bash

############################################################
# This script installs Kubernetes software required in nodes
# in the cluster. To be exectued as the first step
#
# Currently requires ubuntu focal, and a compatibiltiy
# package for Rook is needed: linux-generic-hwe-20.04
#
# I'm experiencing problems with ubuntu 22, where the
# apiserver is lost after installing calico
############################################################

# Abort if error
set -e

# Specific version to install
K8S_VERSION=1.26.0-00

echo "[K8S-INSTALL] Installing K8S $K8S_VERSION"

# Check I'm root
if [[ "$(whoami)" != "root" ]]
then
	echo "Must be root but was $(whoami)";
	exit 1;
fi

# Avoid user prompt for restarting of services. For ubuntu 22
# Calico does not seem to work well with Ubuntu 22
# printf "\$nrconf{restart} = 'a';\n" >> /etc/needrestart/needrestart.conf

echo "[K8S-INSTALL] updating & upgrading..."
apt-get update
apt-get upgrade -y
# Use this for Ubuntu 20. Not needed for Ubuntu 22 which has a higher kernel
# https://pullanswer.com/questions/newly-created-ec-pool-pvc-mounts-fail-operator-fails-to-reconcile
apt-get install -y linux-generic-hwe-20.04
echo "[K8S-INSTALL] done."

# Add to /etc/hosts
if ! grep -q "192.168.122.2" /etc/hosts
then
	echo
	echo "# Added by k8s installer" >> /etc/hosts
	echo "192.168.122.2  vm2" >> /etc/hosts
	echo "192.168.122.3  vm3" >> /etc/hosts
	echo "192.168.122.4  vm4" >> /etc/hosts
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

# Enable iSCSI for OpenEBS
echo "[K8S-INSTALL] Enabiling iscsid..."
systemctl enable --now iscsid
echo "[K8S-INSTALL] done"

# Install Kubernetes components
echo "[K8S-INSTALL] Installing containerd prerequirements..."
apt-get update
apt-get install ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

# Install Containerd
echo "[K8S-INSTALL] Installing containerd..."
apt-get install -y containerd.io

echo "[K8S-INSTALL] Updating containerd for cgroups"
sed -i "s/disabled_plugins/#disabled_plugins/g" /etc/containerd/config.toml 
cat <<EOF >>/etc/containerd/config.toml 

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF
systemctl restart containerd

echo "[K8S-INSTALL] Installing kubeadm..."
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
# Use this to check available versions: apt-cache showpkg <package-name>
# To install a specific version apt-get install -y kubelet=1.21.4-00. Use allow-downgrades because some software may be already installed
apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION --allow-downgrades
apt-mark hold kubelet kubeadm kubectl
echo "[K8S-INSTALL] done."

touch $HOME/K8S_Preinstall_Finished

