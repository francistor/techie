#!/bin/bash

# Debug with kubectl run -i --tty busybox --image=busybox --restart=Never -n profiler -- sh

# Local test
# ./simpleprofiler -client -server [-sync]

# Test existing database
# ./simpleprofiler -client -sqlcredentials root:secret -sqlhostport 192.168.122.2:30006 -debug

# Ceph default storage class
# kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"null"}}}'
# kubectl patch storageclass openebs-jiva-csi-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"null"}}}'
# kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Jiva default storage class
# kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"null"}}}'
# kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"null"}}}'
# kubectl patch storageclass openebs-jiva-csi-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Longhorn default storage class
# kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"null"}}}'
# kubectl patch storageclass openebs-jiva-csi-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"null"}}}'
# kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

pushd descriptors

# Create namespace if it does not exits
kubectl create namespace profiler --dry-run=client -o yaml | kubectl apply -f -

# Create all objects
kubectl apply -f service.yaml && 
kubectl apply -f pvc-server.yaml &&
kubectl apply -f pvc-client.yaml &&
kubectl apply -f pod-server-local.yaml &&
kubectl apply -f pod-client-local.yaml

# Show results
sleep 1
kubectl wait --for=condition=Ready -n profiler pod -l profiler=client
echo
echo Local disk
kubectl -n profiler logs -l profiler=client -f

# Replace by instance with persistent volume
kubectl delete -f pod-server-local.yaml &&
kubectl delete -f pod-client-local.yaml

kubectl apply -f pod-server-pvc.yaml &&
kubectl apply -f pod-client-pvc.yaml

# Show results
sleep 1
kubectl wait --for=condition=Ready --timeout=300s -n profiler pod -l profiler=client 
echo
echo PV disk
kubectl -n profiler logs -l profiler=client -f

# Delete all objects
kubectl delete namespace profiler

popd

