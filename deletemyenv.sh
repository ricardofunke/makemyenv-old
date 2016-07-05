#!/bin/bash

set -e

USER_HOME="/home/vagrant"
TICKETS_DIR="${USER_HOME}/tickets"
DB_SERVER='192.168.110.120'
DB_ADM='admin'
DB_PASS='4c2b2cdcbe7f369d3d01a8f3c5202e37'

if [[ -z $1 ]]; then
  echo 'Error: Please insert a LESA ticket name'
  exit 1
fi

if [[ $1 =~ [a-z]+-[0-9]+ ]]; then
  ticket=$1
else
  echo "Error: Invalid ticket name: \"$1\""
  echo '  Please use a name like: "customer-123"'
  exit 1
fi

if ! [[ -d $TICKETS_DIR/$ticket ]]; then
  echo "The environment for $ticket doesn't exist."
  echo '  Nothing to do. Exiting...'
  exit 1
fi 

dbuser=${ticket//-/}
dbpass=${ticket//-/}
dbname=${ticket//-/}
db="$(grep '$db_type' $TICKETS_DIR/${ticket}/modules/liferay/manifests/init.pp | awk -F'=' '{print $2}' | grep -Eo '[a-z0-9]+')" || (echo 'no $db_type variable'; exit 1)

cd $TICKETS_DIR/$ticket
[[ $(vagrant ssh -c 'pkill java') ]]    || true # should continue even if it fails
#[[ $(sleep 10; vagrant ssh -c 'pkill -9 java') ]] || true # should continue even if it fails
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

mysql -h $DB_SERVER -u $DB_ADM -p${DB_PASS} << END
DROP DATABASE ${dbname};
REVOKE ALL PRIVILEGES ON ${dbname}.* FROM '${dbuser}'@'%';
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
rm -rf $ticket
