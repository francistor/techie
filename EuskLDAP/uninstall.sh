#!/bin/bash

# Script to create the master in Galicia

# Abort if error
set -e

# Check I'm root
if [[ "$(whoami)" != "root" ]]
then
	echo "Must be root but was $(whoami)";
	exit 1;
fi

# Uninstall Openldap
echo uninstalling Openldap
apt-get -y remove slapd

rm -rf /var/lib/ldap
rm -rf /var/lib/ldap-ggc
rm -rf /var/lib/ldap-pv
rm -rf /etc/ldap




