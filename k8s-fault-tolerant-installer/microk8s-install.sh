#!/bin/bash

set -e

# Update
sudo apt-get update && sudo apt-get upgrade -y

# Install microk8s
sudo snap install microk8s --classic --channel=1.27

# The above installation creates a microk8s group
# Add the current user to the group, and change ownership of the .kube file
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube

# Setup kubectl
sudo snap install kubectl --classic
microk8s config > $HOME/.kube/config

# To enable HugePages (mayastor requires at least 1024)
echo vm.nr_hugepages = 1024 | sudo tee -a /etc/sysctl.d/20-microk8s-hugepages.conf
# Restart needed here

# Other mayastor dependencies
sudo apt-get install -y linux-modules-extra-$(uname -r)
sudo modprobe nvme-tcp
echo 'nvme-tcp' | sudo tee -a /etc/modules-load.d/microk8s-mayastor.conf

# Install mayastor
microk8s enable mayastor
kubectl patch storageclass mayastor -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install ingress
microk8s enable ingress

# Install metallb
# Install metallb
START_LB_IP=192.168.122.210
END_LB_IP=192.168.122.219
METALLB_IP_RANGE=$START_LB_IP-$END_LB_IP
# Install metallb
echo "[K8S_POSTINSTALL] Installing Metallb..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml

# Configure metallb
echo "apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_IP_RANGE" | kubectl apply -f -

# Expose using L2
echo "apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system" | kubectl apply -f -

echo "[K8S_POSTINSTALL] Done"

# Setup kubectl
sudo snap install kubectl --classic
microk8s config > $HOME/.kube/config



