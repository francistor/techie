#!/bin/bash

# Install Docker in Ubuntu server

# Install Docker
sudo apt-get install -y docker.io
sudo systemctl enable docker.service
# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Install kubectl
sudo snap install kubectl --classic

# Install jq
sudo apt install -y jq

