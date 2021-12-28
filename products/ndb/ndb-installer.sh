#!/bin/bash

# Dependency not present in Ubuntu 20
sudo apt update && sudo apt install -y libtinfo5

# Download file
curl -L -o /var/tmp/mysql-cluster-8.0.27-linux-glibc2.12-x86_64.tar https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster-8.0.27-linux-glibc2.12-x86_64.tar

# Create user and group
sudo groupadd mysql
sudo useradd -g mysql -s /bin/false mysql

# Decompress files
cd /var/tmp
sudo tar -xvf mysql-cluster-8.0.27-linux-glibc2.12-x86_64.tar
sudo tar -C /usr/local -xzvf mysql-cluster-8.0.27-linux-glibc2.12-x86_64.tar.gz
sudo ln -s /usr/local/mysql-cluster-8.0.27-linux-glibc2.12-x86_64 /usr/local/mysql
cd /usr/local/mysql

# Initialize (then, take note of the password)
sudo bin/mysqld --initialize

# Change permissions. Asll should be owner root group mysql, except data directory which is owned also by mysql
sudo chown -R root .
sudo chown -R mysql data
sudo chgrp -R mysql .

# Init script
sudo cp support-files/mysql.server /etc/init.d/
sudo chmod +x /etc/init.d/mysql.server
sudo update-rc.d mysql.server defaults

# ndb
sudo cp bin/ndbd /usr/local/bin/ndbd
sudo cp bin/ndbmtd /usr/local/bin/ndbmtd
sudo chmod +x /usr/local/bin/ndb*

# management
sudo cp bin/ndb_mgm* /usr/local/bin
sudo chmod +x /usr/local/bin/ndb_mgm*

###################
# Configuration
###################

# In the mysql and ndb nodes, create a /etc/my.cnf file with the contents in the resources section
# It specifies that the engine is ndb and the location of the management server (ndb-connectstring)

# In the management node, create a /var/lib/mysql-cluster/config.ini file with the contents in the 
# resource section

############################
# Startup for the first time
############################

# Management node
sudo ndb_mgmd --initial -f /var/lib/mysql-cluster/config.ini

# Data node
sudo ndbd

############################
# Restart
############################

# Management node
sudo ndb_mgmd -f /var/lib/mysql-cluster/config.ini

# Data node
sudo ndbd

# Check status
ndb_mgm
> show;

# Shutdown



###################
# Use
###################

### mysql machine

# Ensure mysql in the path

# If password was stored in mysql_root_password.txt
mysql -u root -p$(cat mysql_root_password.txt)

# Change password
# https://www.universalclass.com/articles/computers/mysql-administration-managing-users-and-privileges.htm
alter user 'root'@'localhost' identified by '<PASSWORD>'

# Create another user
create user 'francisco'@'%' identified by '<PASSWORD>';
# All persmissions to all database.table from any host
grant all on *.* to 'francisco'@'%';

### In a client machine

# Install mysql client
sudo apt-get install mysql-client

# Load data. Ensure that the storage engine has changed from INNODB to NDBCLUSTER
mysql -u francisco -p<password> -h <mysql-host> < world.sql