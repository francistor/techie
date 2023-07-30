#!/bin/bash

sudo kubeadm init --config kubeadm_init_config.yaml --upload-certs | tee join_cluster.txt
