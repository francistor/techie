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
