#!/bin/bash

# Example
# ./vm-install.sh --name vm2 --ip-address 192.168.122.2 --gw-address 192.168.122.1 --base-image /home/francisco/images/ubuntu20.04-base.qcow2 --size 50G --pubkey /home/francisco/.ssh/id_rsa.pub --memory 1024 --cpu 1

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

usage()
{
  echo "Usage: vm-install 
    --name <vm-name> 
    --ip-address <ip-address>    
    --gw-address <gateway-address>
    --base-image <base-image>
    --size <size-of-image>
    --memory <memory-in-gigabytes>
    --cpu <number-of-cpu>
    --pubkey <path-to-public-key>";
  exit 2
}

if [ -z "$PASSWORD" ]; then
    echo "PASSWORD env variable not set";
    exit 1
fi

# Single colon (:) - Value is required for this option
# Double colon (::) - Value is optional
# No colons - No values are required
PARSED_ARGUMENTS=$(getopt -n vm-install -o "" --longoptions name:,ip-address:,gw-address:,base-image:,size:,memory:,cpu:,pubkey: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    --name)         VM_NAME="$2";       shift 2  ;;
    --ip-address)   IP_ADDRESS="$2";    shift 2  ;;
    --gw-address)   GW_ADDRESS="$2";    shift 2  ;;
    --base-image)   BASE_IMAGE="$2";    shift 2  ;;
    --size)         SIZE="$2";          shift 2  ;;
    --memory)       VM_MEMORY="$2";     shift 2  ;;
    --cpu)          VM_CPU="$2";        shift 2  ;;
    --pubkey)       PUBKEY="$2";        shift 2  ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

if [ -z "$VM_NAME" ] || [ -z "$IP_ADDRESS" ] || [ -z "$GW_ADDRESS" ] || [ -z "$BASE_IMAGE" ] || [ -z "$SIZE" ] || [ -z "$PUBKEY" ] || [ -z "$VM_MEMORY" ] || [ -z "$VM_CPU" ]; then
    echo "Missing parameter"
    usage
fi

SCRATCH_DIR=/tmp/vm-create
mkdir -p $SCRATCH_DIR
IMAGES_DIR=$(dirname "$BASE_IMAGE")

# Cleanup
if virsh list | grep "$VM_NAME"; then
    virsh destroy $VM_NAME
    virsh undefine $VM_NAME
fi
sudo rm -f "$IMAGES_DIR/$VM_NAME.qcow2" $SCRATCH_DIR/user-data $SCRATCH_DIR/meta-data $SCRATCH_DIR/network-data $IMAGES_DIR/cloud-init-$VM_NAME.iso

# Create image with the specified size
qemu-img create -b $BASE_IMAGE -f qcow2 -F qcow2 "$IMAGES_DIR/$VM_NAME.qcow2" $SIZE

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
"| sudo tee $SCRATCH_DIR/user-data

# Generate meta-data
echo "instance-id: $VM_NAME
local-hostname: $VM_NAME
"| sudo tee $SCRATCH_DIR/meta-data

# Generate network-data
echo "version: 2
ethernets:
  ens3:
    dhcp4: false
    addresses: [$IP_ADDRESS/24]
    gateway4: $GW_ADDRESS
    nameservers: 
      addresses: [8.8.8.8]
"| sudo tee $SCRATCH_DIR/network-config

# CDROM with all meta-data
# Volumen name is cidata to be detected by cloudinit
genisoimage -output $IMAGES_DIR/cloud-init-$VM_NAME.iso -V cidata -r -J $SCRATCH_DIR/user-data $SCRATCH_DIR/meta-data $SCRATCH_DIR/network-config

# Create image
# --graphics none to avoid console, vnc for console
# --noautoconsole do not attach to console. Just install and continue
virt-install --name $VM_NAME --memory $VM_MEMORY --vcpus $VM_CPU --disk $IMAGES_DIR/$VM_NAME.qcow2,device=disk,bus=virtio \
  --disk $IMAGES_DIR/cloud-init-$VM_NAME.iso,device=cdrom --os-type linux --virt-type kvm --network network=default,model=virtio\
  --import --graphics none --console pty,target_type=serial --noautoconsole

# Cleanup transient data
sudo rm -f $SCRATCH_DIR/user-data $SCRATCH_DIR/meta-data $SCRATCH_DIR/network-data 
