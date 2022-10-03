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

# Install Openldap
echo installing Openldap
apt-get install slapd=2.4.49+dfsg-2ubuntu1.9
apt-get -y install ldap-utils

# Update apparmor
echo updating apparmor configuration
apparmor-dirs.sh

# Update schemas
echo updating schema
service slapd stop
sudo -u openldap slapadd -n 0 -c -l config/aaa-schema.ldif
service slapdd start

# Create aaa database with root cn=admin,ou=aaa,o=ggc password=admin
echo creating aaa database
mkdir /var/lib/ldap-ggc
chown openldap:openldap /var/lib/ldap-ggc
ldapadd -Y EXTERNAL -H ldapi:/// -f config/create-aaa-database.ldif

# Configure replication
echo configuring replication
ldapadd -Y EXTERNAL -H ldapi:/// -f config/slave/slave-config.ldif

