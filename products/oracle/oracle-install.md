# Oracle installation and operation notes

## Installation

### Operating system
Use Oracle Linux 8.9 `https://yum.oracle.com/oracle-linux-isos.html`

Execute `sudo yum update && sudo yum upgrade`.

Set the spanish locale, if the keyboard is also in spanish. First, install additional locales, and then execute the command for setting the chosen locale

```
sudo dnf install glibc-all-langpacks
sudo localectl set-locale es_ES.UTF-8
```

Execute the preinstall package

```bash
sudo dnf -y install oracle-database-preinstall-21c
```
Download the XE database rpm in `https://www.oracle.com/database/technologies/xe-downloads.html`, and then configure the database.
For Oracle Linux 8 the link is `https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm`
```bash
# Download to local file
curl -L --output oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm https://download.oracle.com/otn-pub/otn_software/db-express/oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm

# Install
sudo dnf -y localinstall oracle-database-xe-21c-1.0-1.ol8.x86_64.rpm

# Configure
sudo /etc/init.d/oracle-xe-21c configure
```

The same password is set for SYS, SYSADMIN and PDBADMIN. An `oracle` user in group `orainst` will be created. This user will have
sysadmin privileges and may connect to the database using sqlplus in the same host, even if the database has not been started.

### Oracle user configuration

Add the following lines to the `.bashrc` file of the `oracle` user. This file is executed every time a bash shell is started
```bash
export ORACLE_SID=XE
export ORAENV_ASK=NO
. /opt/oracle/product/21c/dbhomeXE/bin/oraenv

PATH="/opt/oracle/product/21c/dbhomeXE/bin:$PATH"
```
### Start and stop

Using the `oracle` user and sqlplus, the database can be started and stopped.

Stop database
```
sqlplus / as sysdba
SQL> SHUTDOWN IMMEDIATE;
```

Start database
```
sqlplus / as sysdba
SQL> STARTUP;
SQL> ALTER PLUGGABLE DATABASE ALL OPEN;
```

For automatic startup
```bash
sudo systemctl daemon-reload
sudo systemctl enable oracle-xe-21c
```

For starting and stopping the serivice
```bash
sudo systemctl start|stop oracle-xe-21c
```

## Operation

### Connecting using SQLPLUS

The syntax to connect remotelly is
```
sqlplus <user>[/Password][@/<host-and-port>/<sid> [as sysdba]
```
For connecting locally the host-and-port may be ommited.

Some examples

```
# Connect locally with sysdba privileges and operating system authentication
sqlplus / as sysdba
# or
sqlplus system

# Connect locally to PDB database
sqlplus sys/XEPDB1 as sysdba

# Conect remotelly
sqlplus sys@localhost/XEPDB1 as sysdba

# Connect remotelly with password
sqlplus sys/<pass>@localhost/XEPDB1 as sysdba
```
The `<host-and-port>/SID` part can be replaced by a service name

### The listener

View the status of the listeners, as `oracle` user.
```bash
lsnrctl status
```

To make enterprise manager visible from the outside
```
sqlplus system
SQL> EXEC DBMS_XDB.SETLISTENERLOCALACCESS(FALSE);
```




