#!/bin/bash
 
# Create kubeconfig file
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
  
# Configure usage of Calico CNI
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  
# Untaint master, so that it will accomodate workoads also
K8S_MASTER=$(kubectl get nodes | awk '$3~/master/'| awk '{print $1}')
kubectl taint node $K8S_MASTER node-role.kubernetes.io/master:NoSchedule-

# Enable iSCSI for OpenEBS
sudo systemctl enable --now iscsid

# Install OpenEBS
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml

# Wait until storage class ready
while [[ ! $(kubectl get sc openebs-jiva-default) ]]
do
 echo "Waiting for Jiva storage class to be available"
 sleep 15
done

# Make default storage class. openebs-hostpath may be used  instead of openebs-jiva-default if one-node cluster
kubectl patch storageclass openebs-jiva-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install metallb
DEFAULT_IP=192.168.122.205
METALLB_IP_RANGE=$DEFAULT_IP-$DEFAULT_IP

# Install metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
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
      
# Install Ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.46.0/deploy/static/provider/baremetal/deploy.yaml

