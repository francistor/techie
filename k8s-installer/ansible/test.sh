#!/bin/bash

echo "Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.122.2:6443 --token 0mi40v.qektyrrpn6gfn957 \
	--discovery-token-ca-cert-hash sha256:9f145bc53ca92faa439efccd0311e95422bb69272cd0b42ffa8da072004826da 
"
