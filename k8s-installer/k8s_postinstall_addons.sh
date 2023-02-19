#!/bin/bash

# Approve any pending CSR
for csr in $(kubectl get csr| awk '{print $1}'); do kubectl certificate approve $csr; done


# Install Rook
# Pre-requirements
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.yaml
# Install
git clone --single-branch --branch v1.10.10 https://github.com/rook/rook.git
cd rook/deploy/examples
kubectl create -f crds.yaml -f common.yaml -f operator.yaml
# Use host network for performance
sed -i 's/#provider: host/provider: host/g' cluster.yaml
kubectl create -f cluster.yaml
# Create storageclass
kubectl create -f csi/rbd/storageclass.yaml
# Wait until storage class ready
while [[ ! $(kubectl get sc rook-ceph-block) ]]
do
 echo "[K8S_POSTINSTALL] Waiting for Rook storage class to be available"
 sleep 15
done
# Make default storage class
# kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install OpenEBS. Jiva and Local PV components
# Uses the default Jiva configuration, in which local pod storage. For better performance, a storage pool should be created
echo "[K8S_POSTINSTALL] Installing OpenEBS..."
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml

# Install Jiva csi, policy and storage class
# https://github.com/openebs/jiva-csi
# Operator
kubectl apply -f https://openebs.github.io/charts/jiva-operator.yaml

# Policy
echo "apiVersion: openebs.io/v1alpha1
kind: JivaVolumePolicy
metadata:
  name: example-jivavolumepolicy
  namespace: openebs
spec:
  replicaSC: openebs-hostpath
  target:
    # monitor: false
    replicationFactor: 3
    "| kubectl apply -f -

# StorageClass
echo "apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-jiva-csi-sc
provisioner: jiva.csi.openebs.io
parameters:
  cas-type: jiva
  policy: example-jivavolumepolicy
"| kubectl apply -f -

# Wait until storage class ready
while [[ ! $(kubectl get sc openebs-jiva-csi-sc) ]]
do
 echo "[K8S_POSTINSTALL] Waiting for Jiva storage class to be available"
 sleep 15
done

# Make default storage class. openebs-hostpath may be used  instead of openebs-jiva-default if one-node cluster
# kubectl patch storageclass openebs-jiva-csi-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo "[K8S_POSTINSTALL] Done"

# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.0/deploy/longhorn.yaml
# Create storage class. "longhorn" will be the storage class by default
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.0/examples/storageclass.yaml

# Install metallb
START_LB_IP=192.168.122.210
END_LB_IP=192.168.122.219
METALLB_IP_RANGE=$START_LB_IP-$END_LB_IP
# Install metallb
echo "[K8S_POSTINSTALL] Installing Metallb..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

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
      
# Install Ingress controller. This is deprecated. TODO: Use another version
# Ingress will take the first IP address from the load balancer
echo "[K8S_POSTINSTALL] Installing Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml

# Wait until all pods up
sleep 2
until ! kubectl get pods -A|grep -v STATUS | awk '{print $4}'|grep -v Running|grep -v Completed; do  echo "[K8S_POSTINSTALL] waiting for all pods up"; done

# The end
echo "[K8S_POSTINSTALL] Done"
