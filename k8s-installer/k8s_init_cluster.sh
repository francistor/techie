sudo kubeadm init --config kubeadm_init_config.yaml --apiserver-advertise-address=192.168.122.2 --pod-network-cidr=10.251.0.0/16 | tee join_cluster.txt
