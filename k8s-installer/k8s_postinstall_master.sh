#!/bin/bash
 
# Create kubeconfig file
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Untaint master, so that it will accomodate workoads also
K8S_MASTER=$(kubectl get nodes | awk '$3~/master/'| awk '{print $1}')
kubectl taint node vm2 node-role.kubernetes.io/master:NoSchedule-
  
# Configure usage of Calico CNI
# echo "[K8S_POSTINSTALL] Installing Calico..."
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
# As an alternative, you may use Antrea
echo "[K8S_POSTINSTALL] Installing Antrea..."
kubectl apply -f https://github.com/antrea-io/antrea/releases/download/v1.4.0/antrea.yml
echo "[K8S_POSTINSTALL] Done"

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
    replicationFactor: 1
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
kubectl patch storageclass openebs-jiva-csi-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo "[K8S_POSTINSTALL] Done"

# Install metallb
DEFAULT_IP=192.168.122.205
METALLB_IP_RANGE=$DEFAULT_IP-$DEFAULT_IP

# Install metallb
echo "[K8S_POSTINSTALL] Installing Metallb..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

# Configure metallb
echo "apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $METALLB_IP_RANGE" | kubectl apply -f -
echo "[K8S_POSTINSTALL] Done"
      
# Install Ingress controller. For kubernetes > 1.21 this will not work. An updated version will be required
echo "[K8S_POSTINSTALL] Installing Ingress..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.0/deploy/static/provider/baremetal/deploy.yaml

# Approve pending certificates
for csr in $(kubectl get csr| awk '{print $1}'); do kubectl certificate approve $csr; done

# The end
echo "[K8S_POSTINSTALL] Done"