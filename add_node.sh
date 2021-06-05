#!/bin/bash

node_name=$1
echo adding node $node_name

ssh $node_name "rm -rf techie && git clone https://github.com/francistor/techie.git && cd techie && ./k8s_preinstall_node.sh"
