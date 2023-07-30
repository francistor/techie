#!/bin/bash

# Installs an ubuntu virtual machine using virsh-install and cloud-init, with the specified IP addressing
# Username francisco, with the password specified in an environment variable
# The directory fo the base image specified is used as the folder for new images created
# Cleanup is performed before creation. Images for virtual machines with the same specified name will be deleted

# curl -L -o $HOME/images/jammy-server-cloudimg-amd64.img http://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
# chown libvirt-qemu:kvm $HOME/images/jammy-server-cloudimg-amd64.img
# export PASSWORD=<some password>
# ./vm-install.sh --hostname vm2 --ip-address 192.168.122.2 --gw-address 192.168.122.1 --base-image /home/francisco/images/jammy-server-cloudimg-amd64.img --size 50G --pubkey /home/francisco/.ssh/id_rsa.pub --memory 4096 --cpu 2

# Requires mkpasswd installed (apt-get install whois)

# This is to make sure that the virsh commands executed via shell do see the networks
# https://askubuntu.com/questions/1066230/cannot-execute-virsh-command-through-ssh-on-ubuntu-18-04

SCRATCH_DIR=/tmp/vm-create

export LIBVIRT_DEFAULT_URI=qemu:///system

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

usage()
{
  echo "Usage: vm-install 
    --hostname <index> 
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
PARSED_ARGUMENTS=$(getopt -n vm-install -o "" --longoptions help::,hostname:,ip-address:,gw-address:,base-image:,size:,rawsize:,memory:,cpu:,pubkey:,password: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    --help) 	      usage;		  exit	   ;;
    --hostname)     VM_HOSTNAME="$2";   shift 2  ;;
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

if [ -z "$VM_HOSTNAME" ] || [ -z "$BASE_IMAGE" ] || [ -z "$SIZE" ] || [ -z "$VM_MEMORY" ] || [ -z "$VM_CPU" ] || [ -z "$IP_ADDRESS" ]; then
  echo "Missing parameter"
  usage
fi

if [ -z "$PUBKEY" ]; then
  PUBKEY="$HOME/.ssh/id_rsa.pub"
fi

if [ ! -f $PUBKEY ]
then
	echo $PUBKEY does not exist
  exit
fi

if [ -z "$GW_ADDRESS" ]; then
  GW_ADDRESS="192.168.122.1"
fi

if [ -z "$RAW_SIZE" ]; then
  RAW_SIZE="10"
fi

mkdir -p $SCRATCH_DIR/$VM_HOSTNAME
IMAGES_DIR=$(dirname "$BASE_IMAGE")

# Cleanup
# Destroy domain if running (destroy gives error if not running)
if virsh list | grep "$VM_HOSTNAME"; then
    virsh destroy $VM_HOSTNAME
fi

# Undefine (should have been stopped by the previous command)
if virsh list --all | grep "$VM_HOSTNAME"; then
    virsh undefine $VM_HOSTNAME
fi
rm -f "$IMAGES_DIR/$HOSTNAME.qcow2" $SCRATCH_DIR/$VM_HOSTNAME/user-data $SCRATCH_DIR/$VM_HOSTNAME/meta-data $SCRATCH_DIR/$VM_HOSTNAME/network-data $IMAGES_DIR/cloud-init-$HOSTNAME.iso $IMAGES_DIR/$HOSTNAME.raw

# Create image with the specified size
qemu-img create -b $BASE_IMAGE -f qcow2 -F qcow2 "$IMAGES_DIR/$VM_HOSTNAME.qcow2" $SIZE

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
" > $SCRATCH_DIR/$VM_HOSTNAME/user-data

# Generate meta-data
echo "instance-id: $VM_HOSTNAME
local-hostname: $VM_HOSTNAME
" > $SCRATCH_DIR/$VM_HOSTNAME/meta-data

# Generate network-data
echo "
version: 2
ethernets:
  ens2:
    dhcp4: false
    addresses: [$IP_ADDRESS/24]
    gateway4: $GW_ADDRESS
    nameservers: 
      addresses: [8.8.8.8]
" > $SCRATCH_DIR/$VM_HOSTNAME/network-config

# CDROM with all meta-data
# Volumen name is cidata to be detected by cloudinit
genisoimage -output $IMAGES_DIR/cloud-init-$VM_HOSTNAME.iso -V cidata -r -J $SCRATCH_DIR/$VM_HOSTNAME/user-data $SCRATCH_DIR/$VM_HOSTNAME/meta-data $SCRATCH_DIR/$VM_HOSTNAME/network-config

# Create image
# --graphics none to avoid console, vnc for console
# --noautoconsole do not attach to console. Just install and continue
# Two network interfaces. The second one, with two VLAN and two IP addresses
# Additional raw disk. The specified file should not exist and will be created
virt-install --name $VM_HOSTNAME --memory $VM_MEMORY --vcpus $VM_CPU --disk $IMAGES_DIR/$VM_HOSTNAME.qcow2,device=disk,bus=virtio \
  --disk $IMAGES_DIR/cloud-init-$VM_HOSTNAME.iso,device=cdrom --disk $IMAGES_DIR/$VM_HOSTNAME.raw,device=disk,bus=virtio,size=$RAW_SIZE --os-type generic --virt-type kvm --network network=default,model=virtio\
  --import --graphics none --console pty,target_type=serial --noautoconsole

# Cleanup transient data
rm -rf $SCRATCH_DIR/$VM_HOSTNAME