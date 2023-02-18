#!/bin/bash

rm inserts1.sql > /dev/null
echo "use mysql;" > inserts1.sql
echo "delete from test;" >> inserts1.sql
for n in {1..1000}
do
    # Print the square value
    echo "insert into test (Id, Val) values ($n, $n);" >> inserts1.sql
done

rm inserts2.sql > /dev/null
echo "use mysql;" > inserts2.sql
echo "delete from test;" >> inserts2.sql
for n in {1001..2000}
do
    # Print the square value
    echo "insert into test (Id, Val) values ($n, $n);" >> inserts2.sql
done
