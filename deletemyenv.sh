#!/bin/bash

set -e

USER_HOME="/home/vagrant"
TICKETS_DIR="${USER_HOME}/tickets"

ticket=$1
dbuser=${ticket//-/}
dbpass=${ticket//-/}
dbname=${ticket//-/}
db="$(grep '$db_type' $TICKETS_DIR/${ticket}/modules/liferay/manifests/init.pp | awk -F'=' '{print $2}' | grep -Eo '[a-z0-9]+')"

cd $TICKETS_DIR/$ticket
vagrant ssh 'pkill java'
vagrant ssh 'pkill -9 java'
vagrant destroy
cd $TICKETS_DIR
[[ -n $ticket ]] && rm -rf $ticket

case $db in
  postgresql)

# better not indent heredocs
PGPASSWORD=$DB_PASS psql -h $DB_SERVER -U $DB_ADM postgres << END
DROP DATABASE ${dbname} OWNER ${dbuser};
DROP USER ${dbuser} WITH PASSWORD '${dbpass}';
END

  ;;
  mysql)

mysql -h $DB_SERVER -u $DB_ADM -p $DB_PASS << END
DROP DATABASE ${dbname};
REVOKE ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'%' IDENTIFIED BY '${dbpass}';
DROP USER ${dbuser};
END

  ;;
  mssql)
    isql $DB_SERVER $DB_ADM $DB_PASS -b "DROP DATABASE ${dbname};"
    dbuser='sa'
    dbpass='password'
  ;;
  oracle)

sqlplus ${DB_ADM}/${DB_PASS}@${DB_SERVER}/ORCL << END
ALTER SESSION SET "_ORACLE_SCRIPT"=true;
DROP USER ${dbuser} CASCADE;
END

  ;;
  db2)
  ;;
esac
