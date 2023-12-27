## Show all tables
```
select table_name from user_tables;
```

## Show all users
```
select username from all_users;
```

## Show CDB and PDB

The following commands must be executed from the root container

Show all CDB
```
select name from v$database;
```
Show all PDB
```
select pdb_name from dba_pdbs;
```

## Show datafiles

```
select df.name from v$datafile df
inner join dba_pdbs pdb
    on pdb.con_id = df.con_id
    and pdb.pdb_name = 'XEPDB1';
```

## Operations on tablespaces
Creation

```
create tablespace psa_tbs datafile '/opt/...' size 100M autoextend on;
```

Assign as default

```
alter user <user> set default tablespace <tablespace-name>;

```
```
select * from user_tablespaces;
select * from dba_tablespaces;
select username,default_tablespace from dba_users where username = 'PSA';
```
