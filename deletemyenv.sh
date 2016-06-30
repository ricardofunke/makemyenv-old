#!/bin/bash

set -e

USER_HOME="/home/vagrant"
TICKETS_DIR="${USER_HOME}/tickets"
DB_SERVER='192.168.110.120'
DB_ADM='admin'
DB_PASS='4c2b2cdcbe7f369d3d01a8f3c5202e37'

ticket=$1
dbuser=${ticket//-/}
dbpass=${ticket//-/}
dbname=${ticket//-/}
db="$(grep '$db_type' $TICKETS_DIR/${ticket}/modules/liferay/manifests/init.pp | awk -F'=' '{print $2}' | grep -Eo '[a-z0-9]+')" || (echo 'no $db_type variable'; exit 1)

cd $TICKETS_DIR/$ticket
[[ $(vagrant ssh -c 'pkill java') ]]    || true
[[ $(vagrant ssh -c 'pkill -9 java') ]] || true
vagrant destroy -f

case $db in
  postgresql)

# better not indent heredocs
PGPASSWORD=$DB_PASS psql -h $DB_SERVER -U $DB_ADM postgres << END
DROP DATABASE ${dbname};
DROP USER ${dbuser};
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

cd $TICKETS_DIR
[[ -n $ticket ]] && rm -rf $ticket

