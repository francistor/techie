# K8S Installer

Utility scripts to build a Kubernetes cluster for experimentation in a single Linux Host.

Intended for my personal use only.

## Quickstart

Install `kvm`

Install `mkgpasswd` with `apt-get install whois`

Download the image referenced in `ansible/k8s_install.yaml`

Execute `ansible/k8s_install.sh`

## What is installed

The utility uses kubeadm to create a cluster with N workers and a single master. The CNI plugin is Calico. Three storage classes are created, with Rook Ceph, OpenEBS and Longhorn, in order to compare performance. Additionaly, MetalLB and NGINX are installed as
Load Balancer and Ingress respectively.

## VM Installer

The script `vm-installer/vm-install.sh` builds an Ubuntu Virtual machine using virsh-install and cloud-init, with the specified IP addressing. The username `francisco`, with the password specified in an environment variable `PASSWORD`. The directory fo the base image specified is used as the folder for new images created. Cleanup is performed before creation. Images for virtual machines with the same specified name will be deleted.

An additional network interface is created and connected to a network named `provider_net`, with VLANS 101 and 103.

Download the image with the following commands

```
curl -L -o $HOME/images/focal-server-cloudimg-amd64.img http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
chown libvirt-qemu:kvm $HOME/images/focal-server-cloudimg-amd64.img
```

```
# Example
export PASSWORD=<some password>
./vm-install.sh --vm-index 2 --ip-address 192.168.122.2 --gw-address 192.168.122.1 --base-image /home/francisco/images/focal-server-cloudimg-amd64.img --size 50G --pubkey /home/francisco/.ssh/id_rsa.pub --memory 4096 --cpu 2

# With defaults
# ./vm-install.sh --vm-index 2 --base-image /home/francisco/images/focal-server-cloudimg-amd64.img --size 50G --pubkey /home/francisco/.ssh/id_rsa.pub --memory 1024 --cpu 1
```