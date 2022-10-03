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
apt-get -y install slapd=2.4.49+dfsg-2ubuntu1.9
apt-get -y install ldap-utils

# Update apparmor
echo updating apparmor configuration
apparmor-dirs.sh

# Update schemas
echo updating schemas adding aaa, collective, ppolicy
service slapd stop
sudo -u openldap slapadd -n 0 -c -v -l config/aaa-schema.ldif
service slapd start

# Create aaa database with root cn=admin,ou=aaa,o=ggc password=admin
echo creating aaa database
mkdir /var/lib/ldap-ggc
chown openldap:openldap /var/lib/ldap-ggc
ldapadd -Y EXTERNAL -H ldapi:/// -f config/create-aaa-database.ldif

# Populate with data. Use -q for quick mode
echo populating aaa database
service slapd stop
slapadd -q -n 2 -c -l export/export_AAA_GALICIA.ldif
service slapd start

# Create replication user
echo creating replication user
sudo ldapadd -c -x -wadmin -D "cn=admin,ou=aaa,o=ggc" -f config/galicia-master/replication-user.ldif

# Configure replication as master
echo configuring replication
ldapadd -Y EXTERNAL -H ldapi:/// -f config/galicia-master/master-config.ldif

