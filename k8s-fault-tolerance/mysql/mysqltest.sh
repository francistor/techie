#!/bin/bash

# Create mysql main instances (2)
kubectl apply -n mysql -f main.yaml
sleep 1
kubectl wait --for=condition=Ready -n mysql pod mysql-main-0
sleep 1
kubectl wait --for=condition=Ready -n mysql pod mysql-main-1

# Configure bidirectional replication among the two main instances
kubectl apply -n mysql -f main-config-job.yaml

# Load schema
cat schema.sql | mysql -h vm2 -P 30007 -u root -psecret

# Load one millon entries
echo "starting data load at $(date)"
echo "call populate(1000000); commit;"|mysql -h vm2 -P 30007 -u root -psecret --init-command="set autocommit=0;" -D PSBA
echo "finished data load at $(date)"

# Create one replica
echo "starting data load at $(date)"
kubectl -n mysql apply -f replicas.yaml


# Delete one of the main instances
kubectl scale statefulset mysql-main -n mysql --replicas=1
sleep 2
kubectl delete pvc data-mysql-main-1 -n mysql
sleep 2

# Recreate
kubectl -n mysql scale statefulset mysql-main --replicas=2
sleep 1

# Reconfigure
kubectl -n mysql apply -f main-reconfig-job.yaml
sleep 1
kubectl logs -n mysql -l job=main-reconfig -f 



