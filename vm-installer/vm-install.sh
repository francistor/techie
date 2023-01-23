#!/bin/bash

# Installs an ubuntu virtual machine using virsh-install and cloud-init, with the specified IP addressing
# Username francisco, with the password specified in an environment variable
# The directory fo the base image specified is used as the folder for new images created
# Cleanup is performed before creation. Images for virtual machines with the same specified name will be deleted

# Additional interface in provider_net

# curl -L -o $HOME/images/focal-server-cloudimg-amd64.img http://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
# chown libvirt-qemu:kvm $HOME/images/focal-server-cloudimg-amd64.img

# Example# curl https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
# export PASSWORD=<some password>
# ./vm-install.sh --vm-index 2 --ip-address 192.168.122.2 --gw-address 192.168.122.1 --base-image /home/francisco/images/focal-server-cloudimg-amd64.img --size 50G --pubkey /home/francisco/.ssh/id_rsa.pub --memory 4096 --cpu 2
# With defaults
# ./vm-install.sh --vm-index 2 --base-image /home/francisco/images/focal-server-cloudimg-amd64.img --size 50G --pubkey /home/francisco/.ssh/id_rsa.pub --memory 1024 --cpu 1

# Requires mkpasswd installed (apt-get install whois)

# This is to make sure that the virsh commands executed via shell do see the networks
# https://askubuntu.com/questions/1066230/cannot-execute-virsh-command-through-ssh-on-ubuntu-18-04
export LIBVIRT_DEFAULT_URI=qemu:///system

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

usage()
{
  echo "Usage: vm-install 
    --vm-index <index> 
    --ip-address <ip-address>    
    --gw-address <gateway-address>
    --base-image <base-image>
    --size <size-of-image> plus \"G\"
    --rawsize <size-of-additional-raw-disk> without \"G\"
    --memory <memory-in-gigabytes>
    --cpu <number-of-cpu>
    --pubkey <path-to-public-key>";
  exit 2
}

# Single colon (:) - Value is required for this option
# Double colon (::) - Value is optional
# No colons - No values are required
PARSED_ARGUMENTS=$(getopt -n vm-install -o "" --longoptions help::,vm-index:,ip-address:,gw-address:,base-image:,size:,rawsize:,memory:,cpu:,pubkey:,password: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    --help) 	     usage;		  exit	   ;;
    --vm-index)     VM_INDEX="$2";      shift 2  ;;
    --ip-address)   IP_ADDRESS="$2";    shift 2  ;;
    --gw-address)   GW_ADDRESS="$2";    shift 2  ;;
    --base-image)   BASE_IMAGE="$2";    shift 2  ;;
    --size)         SIZE="$2";          shift 2  ;;
    --rawsize)      RAW_SIZE="$2";      shift 2  ;;
    --memory)       VM_MEMORY="$2";     shift 2  ;;
    --cpu)          VM_CPU="$2";        shift 2  ;;
    --pubkey)       PUBKEY="$2";        shift 2  ;;
    --netindex)     NET_INDEX="$2";     shift 2  ;;
    --password)     PASSWORD="$2";      shift 2  ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

if [ -z "$PASSWORD" ]; then
    echo "PASSWORD env variable not set";
    exit 1
fi

if [ -z "$VM_INDEX" ] || [ -z "$BASE_IMAGE" ] || [ -z "$SIZE" ] || [ -z "$PUBKEY" ] || [ -z "$VM_MEMORY" ] || [ -z "$VM_CPU" ]; then
  echo "Missing parameter"
  usage
fi

if [ "$VM_INDEX" == "1" ]; then
    echo "VM Index cannot be 1"
    exit
fi

# Set defaults
if [ -z "$IP_ADDRESS" ]; then
  IP_ADDRESS="192.168.122.$VM_INDEX"
fi

if [ -z "$GW_ADDRESS" ]; then
  GW_ADDRESS="192.168.122.1"
fi

if [ -z "$RAW_SIZE" ]; then
  RAW_SIZE="10"
fi

SCRATCH_DIR=/tmp/vm-create
mkdir -p $SCRATCH_DIR
IMAGES_DIR=$(dirname "$BASE_IMAGE")

# Cleanup
# Destroy domain if running (destroy gives error if not running)
if virsh list | grep "vm$VM_INDEX"; then
    virsh destroy vm$VM_INDEX
fi

# Undefine (should have been stopped by the previous command)
if virsh list --all | grep "vm$VM_INDEX"; then
    virsh undefine vm$VM_INDEX
fi
rm -f "$IMAGES_DIR/vm$VM_INDEX.qcow2" $SCRATCH_DIR/user-data $SCRATCH_DIR/meta-data $SCRATCH_DIR/network-data $IMAGES_DIR/cloud-init-vm$VM_INDEX.iso $IMAGES_DIR/vm$VM_INDEX.raw

# Create image with the specified size
qemu-img create -b $BASE_IMAGE -f qcow2 -F qcow2 "$IMAGES_DIR/vm$VM_INDEX.qcow2" $SIZE

# Generate user-data
# chpasswd needs multistring format (using |) and no space between username and password
echo "#cloud-config
users:
  - name: francisco
    lock_passwd: false
    passwd: $(echo $PASSWORD | mkpasswd -s --method=SHA-512 --rounds=4096)
    ssh_authorized_keys:
      - $(cat $PUBKEY)
    sudo: ['ALL=(ALL) NOPASSWD: ALL']
    groups: sudo
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  expire: false
  list: |
    francisco:$PASSWORD
disable_root: false
" > $SCRATCH_DIR/user-data

# Generate meta-data
echo "instance-id: vm$VM_INDEX
local-hostname: vm$VM_INDEX
" > $SCRATCH_DIR/meta-data

# Generate network-data
echo "
version: 2
ethernets:
  dummy0:
    match: 
      name: ens2
    dhcp4: false
    addresses: [$IP_ADDRESS/24]
    gateway4: $GW_ADDRESS
    nameservers: 
      addresses: [8.8.8.8]
  ens3: {}
vlans:
  vlan101:
    id: 101
    link: ens3
    addresses:
    - 192.168.101.$VM_INDEX/24
  vlan102:
    id: 102
    link: ens3
    addresses:
    - 192.168.102.$VM_INDEX/24
" > $SCRATCH_DIR/network-config

# CDROM with all meta-data
# Volumen name is cidata to be detected by cloudinit
genisoimage -output $IMAGES_DIR/cloud-init-vm$VM_INDEX.iso -V cidata -r -J $SCRATCH_DIR/user-data $SCRATCH_DIR/meta-data $SCRATCH_DIR/network-config

# Create image
# --graphics none to avoid console, vnc for console
# --noautoconsole do not attach to console. Just install and continue
# Two network interfaces. The second one, with two VLAN and two IP addresses
# Additional raw disk. The specified file should not exist and will be created
virt-install --name vm$VM_INDEX --memory $VM_MEMORY --vcpus $VM_CPU --disk $IMAGES_DIR/vm$VM_INDEX.qcow2,device=disk,bus=virtio \
  --disk $IMAGES_DIR/cloud-init-vm$VM_INDEX.iso,device=cdrom --disk $IMAGES_DIR/vm$VM_INDEX.raw,device=disk,bus=virtio,size=$RAW_SIZE --os-type generic --virt-type kvm --network network=default,model=virtio\
  --network network=provider-net,model=virtio --import --graphics none --console pty,target_type=serial --noautoconsole

# Cleanup transient data
rm -f $SCRATCH_DIR/user-data $SCRATCH_DIR/meta-data $SCRATCH_DIR/network-config

# Generate network-data using VLAN

