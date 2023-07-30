## Hints

Connect to mysql-0

```
mysql -h vm2 -P 30007 -u root -psecret
```

Load schema

```
cat schema.sql | mysql -h vm2 -P 30007 -u root -psecret
```

Load One million entries

```
echo "call populate(1000000); commit;"|mysql -h vm2 -P 30007 -u root -psecret --init-command="set autocommit=0;" -D PSBA
```

Create replica

```
kubectl apply -n mysql -f replicas.yaml
```

Check how long it took to replicate

```
(kubectl -n mysql exec -it mysql-replica-0 -- tail -f /tmp/postStart.log) | sed '/finished/Q'
```

Check number of entries in replica

```
kubectl -n mysql exec -it mysql-replica-0 -- (echo "select count(1) from clients" | mysql -h 127.0.0.1 -u root -psecret -D PSBA)
```



