#!/bin/bash

# Installs and configures keepalived
# Must be executed as root
# example
# ./install.sh --state MASTER --interface ens2 --vip-address 192.168.122.10

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

usage()
{
  echo "Usage: keepalived-install 
    --state <MASTER|BACKUP> 
    --interface <ens2>    
    --vip-address <vip-address>;"
  exit 2
}

# Single colon (:) - Value is required for this option
# Double colon (::) - Value is optional
# No colons - No values are required
PARSED_ARGUMENTS=$(getopt -n keepalived-install -o "" --longoptions "help::,state:,interface:,vip-address:" -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    --help) 	     usage;		            exit	 ;;
    --state)         STATE="$2";            shift 2  ;;
    --interface)     INTERFACE="$2";        shift 2  ;;
    --vip-address)   APISERVER_VIP="$2";    shift 2  ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

echo $STATE THIS IS THE STATE

if [ "${STATE}" = "MASTER" ]
then
    PRIORITY=101;
else
    PRIORITY=100;
fi

# Install keepalived
apt-get -y install keepalived
echo keepalived installed

# Keepalived configuration file
cat <<EOF > /etc/keepalived/keepalived.conf
! /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state ${STATE}
    interface ${INTERFACE}
    virtual_router_id 51
    priority ${PRIORITY}
    authentication {
        auth_type PASS
        auth_pass verysecretpassword99
    }
    virtual_ipaddress {
        ${APISERVER_VIP}
    }
    track_script {
        check_apiserver
    }
}
EOF
echo configuration file written

# Keepalived health check file
cat <<EOF > /etc/keepalived/check_apiserver.sh
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q ${APISERVER_VIP}; then
    curl --silent --max-time 2 --insecure https://${APISERVER_VIP}:6443/ -o /dev/null || errorExit "Error GET https://${APISERVER_VIP}:6443/"
fi
EOF
echo health check script written

# Permissions for executable health check script
chmod +x /etc/keepalived/check_apiserver.sh

# Take the changes
systemctl restart keepalived

# Install haproxy
apt-get install haproxy

# Configure haproxy
cat <<EOF > /etc/haproxy/haproxy.cfg

# /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s

#---------------------------------------------------------------------
# apiserver frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend apiserver
    bind *:6445
    mode tcp
    option tcplog
    default_backend apiserver

#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance     roundrobin
        server vm2 192.168.122.2:6445 check
        server vm3 192.168.122.3:6445 check
        server vm4 192.168.122.4:6445 check
        # server ${HOST1_ID} ${HOST1_ADDRESS}:${APISERVER_SRC_PORT} check
EOF

# Take the changes
systemctl restart keepalived

