#!/bin/bash
 
# Create kubeconfig file
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Untaint master, so that it will accomodate workoads also
# delete this line! K8S_MASTER=$(kubectl get nodes | awk '$3~/master/'| awk '{print $1}')
kubectl taint node vm2 node-role.kubernetes.io/control-plane:NoSchedule-

# Approve pending certificates
for csr in $(kubectl get csr| awk '{print $1}'); do kubectl certificate approve $csr; done
  
# Configure usage of Calico CNI
# echo "[K8S_POSTINSTALL] Installing Calico..."
# Install the operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
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
spec: {}" | kubectl apply -f -

# As an alternative, you may use Antrea
# echo "[K8S_POSTINSTALL] Installing Antrea..."
# kubectl apply -f https://github.com/antrea-io/antrea/releases/download/v1.4.0/antrea.yml
echo "[K8S_POSTINSTALL] Done"

# Wait for Calico up
ONE_POD_RUNNING="false";
CALICO_RUNNING="false";
while [ "$CALICO_RUNNING" == "false" ] || [ "$ONE_POD_RUNNING" == "false" ]
do
 	echo "[K8S_POSTINSTALL] Waiting for Calico to be available";
 	sleep 1;
 	
 	CALICO_RUNNING="true";
	for PodStatus in $(kubectl get pods -n calico-system|grep -v STATUS | awk '{print $3}')
	do 
	  echo $PodStatus;
	  ONE_POD_RUNNING="true";
	  
	  if [ "$PodStatus" != "Running" ]
	  then
	  	CALICO_RUNNING="false";
	  fi
	done
done



