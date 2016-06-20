#!/bin/bash

# Runing without parameters prints help message
if [[ $@ == "" ]]; then
  $0 -h
fi

while getopts 't:v:o:a:p:j:d:l:s:h' opt; do
  case $opt in
    t)
      if [[ $OPTARG =~ [a-z]+-[0-9]+ ]]; then
        ticket=$OPTARG
      else
        echo "Error: Invalid ticket name: \"$OPTARG\""
        echo '  Please use a name like: "abc-123"'
        exit 1
      fi
    ;;
    v)
      case $OPTARG in 
        6110|6120|6130|6210)
          lrver=$OPTARG
        ;;
        *)
          echo "Error: Liferay version not supported: \"$OPTARG\""
          echo '  Please use 6110, 6120, 6130 or 6210'
          exit 1
        ;;
      esac
    ;;
    o)
      case $OPTARG in
        linux|windows)
          os=$OPTARG
        ;;
        *)
          echo "Error: Operating System not supported: \"$OPTARG\""
          echo '  Please use linux or windows'
          exit 1
        ;;
      esac
    ;;
    a)
      case $OPTARG in
        tomcat|jboss|websphere|weblogic)
          as=$OPTARG
        ;;
        *)
          echo "Error: Application Server not supported: \"$OPTARG\""
          echo '  Please use tomcat, jboss, websphere or weblogic'
          exit 1
        ;;
      esac
    ;;
    p)
      if [[ $OPTARG =~ (portal|hotfix)-[0-9]+-(6130|6210) ]]; then
        patch=$OPTARG
      else
        echo "Error: Invalid patch name: \"$OPTARG\""
        echo '  Please insert a patch name like: "[portal|hotfix]-123-[6130|6210]"'
        exit 1 
      fi
    ;;
    j)
      case $OPTARG in 
        6|7|8)
          java=$OPTARG
        ;;
        *)
          echo "Error: Java version not supported: \"$OPTARG\""
          echo '  Please use 6, 7 or 8 for the Java version'
          exit 1
        ;;
      esac
    ;;
    d)
      case $OPTARG in
        postgresql|mysql|mssql|oracle|db2)
          db=$OPTARG
        ;;
        *)
          echo "Error: Database not supported: \"$OPTARG\""
          echo '  Please use postgresql, mysql, mssql, oracle or db2'
          exit 1
        ;;
      esac
    ;;
    l)
      case $OPTARG in
        ad|openldap)
          ldap=$OPTARG
        ;;
        *)
          echo "Error: LDAP server not supported: \"$OPTARG\""
          echo '  Please use ad or openldap'
          exit 1
        ;;
      esac
    ;;
    s)
      case $OPTARG in
        *) 
         sso=$OPTARG
         echo 'SSO support not implemented yet!'
         exit 1
        ;;
      esac
    ;;
    h)
      echo "Version 0.1"
      echo '--'
      echo "Usage: $0 [options]"
      echo
      echo 'Options:'
      echo '   -t <ticket-name>         Insert the LESA ticket name'
      echo '                            <required>'
      echo
      echo '   -v <liferay-version>     Insert the Liferay version without dots'
      echo '                            default: <6210>'
      echo
      echo '   -o <operating-system>    Insert the Operating System for Liferay'
      echo '                            default: <linux>'
      echo
      echo '   -a <application-server>  Insert the Application Server for Liferay'
      echo '                            default: <tomcat>'
      echo
      echo '   -p <patch>               Insert the patch (hotfix or fix-pack) for Liferay'
      echo '                            default: <none>'
      echo
      echo '   -j <java-version>        Insert the Java Version for Liferay'
      echo '                            default: <6>'
      echo
      echo '   -d <database>            Insert the Database for Liferay'
      echo '                            default: <postgresql>'
      echo
      echo '   -l <ldap-server>         Insert the LDAP Server to integrate with Liferay'
      echo '                            default: <none>'
      echo
      echo '   -s <sso-method>          Insert the SSO method to integrate with Liferay'
      echo '                            default: <none>'
      echo
      echo '   -h                       Show this message'
      echo
      exit 0
    ;;
    \?)
      $0 -h
    ;;
  esac
done

if [[ -z $ticket ]]; then
  echo 'Error: The -t option is required'
  echo '  Please insert a ticket name'
  exit 1
fi

# Setting default values
: ${lrver:=6210}
: ${os:=linux}
: ${as:=tomcat}
: ${patch:=}
: ${java:=6}
: ${db:=postgresql}
: ${ldap:=}
: ${sso:=}

if [[ $lrver != ${patch##*-} ]]; then
  echo "Error: The patch inserted \"${patch}\" doesn't match Liferay version \"${lrver}\""
  echo '  Please use a patch compatible with the Liferay version selected'
  exit 1
fi

BOX_URL='http://192.168.110.251/vagrant-boxes'
DB_SERVER='192.168.110.120'
DB_ADM='admin'
DB_PASS='4c2b2cdcbe7f369d3d01a8f3c5202e37'

# Create DB
dbuser=${ticket//-/}
dbpass=${ticket//-/}
dbname=${ticket//-/}

case $db in
  postgresql)
    PGPASSWORD=$DB_PASS psql -h $DB_SERVER -U $DB_ADM posgres << EOF
     CREATE USER ${dbuser} WITH PASSWORD '${dbpass}';
     CREATE DATABASE ${dbname} OWNER ${dbuser};
EOF
  ;;
  mysql)
    mysql -h $DB_SERVER -u $DB_ADM -p $DB_PASS << EOF
      CREATE DATABASE ${dbname};
      GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'%' IDENTIFIED BY '${dbpass}';
EOF
  ;;
  mssql)
    isql $DB_SERVER $DB_ADM $DB_PASS -b "CREATE DATABASE ${dbname}"
    dbuser='sa'
    dbpass='password'
  ;;
  oracle)
    sqlplus ${DB_ADM}/${DB_PASS}@${DB_SERVER}/ORCL << EOF
      ALTER SESSION SET "_ORACLE_SCRIPT"=true;
      CREATE USER ${dbuser} IDENTIFIED BY ${dbpass} DEFAULT TABLESPACE USERS;
      GRANT UNLIMITED TABLESPACE TO ${dbuser};
EOF
  ;;
  db2)
  ;;
esac

# Prepare vagrant user directory
cd tickets && mkdir $ticket && cd $ticket

# Prepare user portal-ext.properties
cat ../props-templates/db/${db}-portal-ext.properties >> portal-ext.properties
[[ -n $ldap ]] && cat ../props-templates/ldap/${ldap}-portal-ext.properties >> portal-ext.properties
[[ -n $sso ]] && cat ../props-templates/sso/${sso}-portal-ext.properties >> portal-ext.properties

sed -i "s/@@USER@@/${dbuser}" portal-ext.properties
sed -i "s/@@PASS@@/${dbpass}" portal-ext.properties

# If Linux with tomcat or jboss let's use puppet to install Liferay
if [[ $os == "linux" && $as =~ (tomcat|jboss) ]]; then

  mkdir manifests && cp ../puppet-templates/manifests/java-as-lrver.pp manifests/default.pp
  cp -r ../puppet-templates/modules/ .

  sed -i "s/@@JAVA@@/${java}/"    manifests/default.pp
  sed -i "s/@@AS@@/${as}/"        manifests/default.pp
  sed -i "s/@@LRVER@@/${lrver}/"  manifests/default.pp

  vagrant init -m $ticket $BOX_URL/ubuntu.box

# If not tomcat or jboss, use puppet only for java installation and a box already prepared for the rest of the job
elif [[ $os == "linux" ]]; then

  mkdir manifests && cp ../puppet-templates/manifests/java.pp manifests/default.pp
  cp -r ../puppet-templates/modules/ .

  sed -i "s/@@JAVA@@/${java}/"    manifests/default.pp

  vagrant init -m $ticket $BOX_URL/liferay-${lrver}-${as}-${os}.box

fi

# Configure Java version
# case $os in
#   linux)
#     vagrant ssh -c "sudo update-java-alternatives -s java-${java}-oracle"
#   ;;
#   windows)
#     vagrant ssh -c "home/liferay/jdk${java}.bat"
#   ;;
# esac

vagrant up
vagrant ssh -c "/home/liferay/liferay-${lrver}/patching-tool.sh download ${patch}"
vagrant ssh -c "/home/liferay/liferay-${lrver}/patching-tool.sh install ${patch}"
