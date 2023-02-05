#!/bin/bash

version=0.1

# Better at the beginning
echo "DockerHub password"
sudo -E docker login --username=francistor

# Generate docker image
sudo docker build --file dockerfile --build-arg version=$version --tag simpleprofiler:$version .

# Publish to docker hub
sudo docker tag simpleprofiler:$version francistor/simpleprofiler:$version
sudo docker push francistor/simpleprofiler:$version