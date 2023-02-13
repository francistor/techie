#!/bin/bash

version=0.2

# Better at the beginning
echo "DockerHub password"
docker login --username=francistor || exit 1

# Generate docker image
docker build --file dockerfile --build-arg version=$version --tag simpleprofiler:$version .

# Publish to docker hub
docker tag simpleprofiler:$version francistor/simpleprofiler:$version
docker push francistor/simpleprofiler:$version