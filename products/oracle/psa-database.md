# PSA database creation on XE

In the database host, connect with user `sys` and issue database creation command

```
sqlplus / as sysdba
SQLPLUS> create pluggable database psa admin user psa identified by psa file_name_convert = ('/opt/oracle/oradata/XE/pdbseed', '/opt/oracle/oradata/XE/PSA');
SQLPLUS> alter pluggable database psa open read write;
```



