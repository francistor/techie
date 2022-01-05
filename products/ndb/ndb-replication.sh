#!/bin/bash

# Setup of replication among ndb clusters

# In the source
# Create a replication account on the source Cluster with the appropriate privileges, using the following two SQL statements as mysql root
CREATE USER 'replication-user'@'192.168.122.32' IDENTIFIED BY 'replicationpwd';
alter user 'replication-user'@'192.168.122.32' identified with mysql_native_password by 'replicationpwd'; # To avoid security error
GRANT REPLICATION SLAVE ON *.* TO 'replication-user'@'192.168.122.32';

# In the replica
CHANGE REPLICATION SOURCE TO SOURCE_HOST='192.168.122.22', SOURCE_PORT=3306, SOURCE_USER='replication-user', SOURCE_PASSWORD='replicationpwd';

# In the master
# Create a backup
ndb_mgm -e "START BACKUP"

# Copy the files generated on each ndb node to the mysql server in the replica, for instance in /var/BACKUP/BACKUP-<N>
# The files are located in /var/lib/mysql/BACKUP/BACKUP-<N>

# In the mysql server
sudo mkdir /var/BACKUP
sudo mkdir /var/BACKUP/BACKUP-1
sudo chmod 777 /var/BACKUP
sudo chmod 777 /var/BACKUP/BACKUP-1

# Edit the my.cnf file in the replica mysql to include "skip-slave-start"

# In the replica
RESET REPLICA;

# Ensure the database does not exist (DROP DATABASE <NAME>)

# Restore in mysql, executing one command for each data node from which the backup was taken (--nodeid)

# The first one should include --restore-meta to create the tables
./ndb_restore --connect-string 192.168.122.31 --nodeid 3 --backupid 1 --restore-data --restore-meta --backup-path /var/BACKUP/BACKUP-1
# The last one should include --restore-epoch
./ndb_restore --connect-string 192.168.122.31 --nodeid 4 --backupid 1 --restore-data --restore-epoch --backup-path /var/BACKUP/BACKUP-1

# Enable binlogs in the master. Include the following options in my.cnf of mysql and restart
# ndbcluster
# server-id=id 
# log-bin
# ndb-log-bin

# In the replica, if it is a fresh replication (no binlogs enabled on the source before the backup was taken)
CHANGE MASTER TO MASTER_LOG_FILE='', MASTER_LOG_POS=4;
START REPLICA;

# To get the position to start the replica
# In the replica
SELECT @latest:=MAX(epoch) FROM mysql.ndb_apply_status;
# In the master
SELECT @file:=SUBSTRING_INDEX(next_file, '/', -1), @pos:=next_position FROM mysql.ndb_binlog_index WHERE epoch >= @latest ORDER BY epoch ASC LIMIT 1;
# In the replica
CHANGE REPLICATION SOURCE TO SOURCE_LOG_FILE='@file', SOURCE_LOG_POS=@pos;

# binlog_expire_logs_seconds to configure the expiration of the binlogs

# To check the replication status
SHOW SLAVE STATUS;




