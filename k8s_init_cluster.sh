sudo kubeadm init --apiserver-advertise-address=192.168.122.2 --pod-network-cidr=10.251.0.0/16 | tee join_cluster.txt
