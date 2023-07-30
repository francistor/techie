#!/bin/bash

# Installs calico
# The parameter is the kubeconfig file
KUBECONFIG=$1

# Untaint master, so that it will accomodate workoads also
kubectl taint node vm2 node-role.kubernetes.io/control-plane:NoSchedule-

# Approve pending certificates
for csr in $(kubectl  get csr| grep -v NAME | awk '{print $1}'); do kubectl certificate approve $csr; done
  
# Configure usage of Calico CNI
# echo "[K8S_POSTINSTALL] Installing Calico..."
# Install the operator
kubectl  create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
# Install the crd for calico
# Taken from kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
echo "apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 10.251.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()" | kubectl apply -f -
      
echo "apiVersion: operator.tigera.io/v1
kind: APIServer 
metadata: 
  name: default 
spec: {}" | kubectl  apply -f -

# As an alternative, you may use Antrea
# echo "[K8S_POSTINSTALL] Installing Antrea..."
# kubectl apply -f https://github.com/antrea-io/antrea/releases/download/v1.4.0/antrea.yml
echo "[K8S_POSTINSTALL] Done"

# Wait for Calico up
kubectl wait pods -n calico-system --for condition=Ready --all --timeout=300s



