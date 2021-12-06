#!/bin/bash

# Install metrics server
# This requires the kubelet not using self-signed-certificates. This is acomplished in kubeadm init passing
# the required configuration file. If the cluster is already setup, follow the instructions in
# https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/, including the later manual
# approval of the CSR

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install Kube Prometheus
rm -rf /tmp/prometheus-operator
git clone https://github.com/prometheus-operator/kube-prometheus.git /tmp/kube-prometheus
pushd /tmp/kube-prometheus
kubectl apply --server-side -f manifests/setup
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
kubectl apply -f manifests/
popd


