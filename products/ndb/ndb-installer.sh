#!/bin/bash

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
sudo cd /usr/local/mysql

# Initialize
sudo bin/mysqld --initialize

# Change permissions
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


