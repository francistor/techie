# PSA database creation on XE

In the database host, connect with user `sys` and issue database creation command

```
sqlplus / as sysdba
SQLPLUS> create pluggable database psa admin user psa identified by psa file_name_convert = ('/opt/oracle/oradata/XE/pdbseed', '/opt/oracle/oradata/XE/PSA');
SQLPLUS> alter pluggable database psa open read write;
GRANT CONNECT TO psa with admin option;
GRANT RESOURCE TO psa with admin option;
GRANT UNLIMITED TABLESPACE TO psa;
GRANT DBA TO psa with admin option;
GRANT CREATE PROCEDURE TO psa;
GRANT CREATE ANY TRIGGER to psa;
GRANT ADMINISTER DATABASE TRIGGER to psa;
GRANT CREATE VIEW TO psa;
GRANT CREATE USER, DROP USER, ALTER USER TO psa;
GRANT GRANT ANY ROLE TO psa;
```

Create the schema objects using user psa
```
sqlplus psa/psa@localhost/psa;
SQLPLUS>@path-to-schema-script.sql
```

Create another user with less privleges

```
sqlplus psa@localhost/psa;
SQLPLUS> create user psauser identified by psauser;
GRANT CONNECT to psauser;
GRANT SELECT ANY TABLE to psauser;
GRANT INSERT ANY TABLE to psauser;
GRANT EXECUTE ANY PRODECURE to psauser;
```



