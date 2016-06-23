#!/bin/bash

show_usage(){
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
}

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
      show_usage
      exit 0
    ;;
    : | \? | *)
      show_usage
      exit 1
  esac
done

# Runing without parameters prints help message
if [[ -z $@ ]]; then
  show_usage
  exit 1
fi

# Parsing arguments without less signal
if [[ -z $OPTARG && $OPTIND == 1 ]]; then
  show_usage
  exit 1
fi

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

# Create DB for the new environment
HTTP_SERVER='http://192.168.110.251'
BOX_URL="${HTTP_SERVER}/vagrant-boxes"
DB_SERVER='192.168.110.120'
DB_ADM='admin'
DB_PASS='4c2b2cdcbe7f369d3d01a8f3c5202e37'

dbuser=${ticket//-/}
dbpass=${ticket//-/}
dbname=${ticket//-/}

case $db in
  postgresql)

# better not indent heredocs
PGPASSWORD=$DB_PASS psql -h $DB_SERVER -U $DB_ADM postgres << END
CREATE USER ${dbuser} WITH PASSWORD '${dbpass}';
CREATE DATABASE ${dbname} OWNER ${dbuser};
END

    [[ $? -ne 0 ]] && exit 1
  ;;
  mysql)

mysql -h $DB_SERVER -u $DB_ADM -p $DB_PASS << END
CREATE DATABASE ${dbname};
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'%' IDENTIFIED BY '${dbpass}';
END

    [[ $? -ne 0 ]] && exit 1
  ;;
  mssql)
    isql $DB_SERVER $DB_ADM $DB_PASS -b "CREATE DATABASE ${dbname}"
    dbuser='sa'
    dbpass='password'
    [[ $? -ne 0 ]] && exit 1
  ;;
  oracle)

sqlplus ${DB_ADM}/${DB_PASS}@${DB_SERVER}/ORCL << END
ALTER SESSION SET "_ORACLE_SCRIPT"=true;
CREATE USER ${dbuser} IDENTIFIED BY ${dbpass} DEFAULT TABLESPACE USERS;
GRANT UNLIMITED TABLESPACE TO ${dbuser};
END

    [[ $? -ne 0 ]] && exit 1
  ;;
  db2)
  ;;
esac

USER_HOME="/home/vagrant"
TICKETS_DIR="${USER_HOME}/tickets"
PROPS_TPL_DIR="${USER_HOME}/props-templates"
PUPPET_TPL_DIR="${USER_HOME}/puppet-templates"
DB_DRIVERS_DIR="${USER_HOME}/db-drivers"

# Prepare vagrant user directory
cd $TICKETS_DIR && mkdir $ticket && cd $ticket || exit 1

# Prepare user portal-ext.properties
cat ${PROPS_TPL_DIR}/db/${db}-portal-ext.properties >> portal-ext.properties || exit 1
if [[ -n $ldap ]]; then
  cat ${PROPS_TPL_DIR}/ldap/${ldap}-portal-ext.properties >> portal-ext.properties || exit 1
fi
if [[ -n $sso ]]; then
  cat ${PROPS_TPL_DIR}/sso/${sso}-portal-ext.properties >> portal-ext.properties || exit 1
fi

sed -i "s/@@DB_SERVER@@/${DB_SERVER}/" portal-ext.properties || exit 1
sed -i "s/@@DBNAME@@/${dbname}/"       portal-ext.properties || exit 1
sed -i "s/@@DBUSER@@/${dbuser}/"       portal-ext.properties || exit 1
sed -i "s/@@DBPASS@@/${dbpass}/"       portal-ext.properties || exit 1

# If Linux with tomcat or jboss let's use puppet to install Liferay
if [[ $os == "linux" && $as =~ (tomcat|jboss) ]]; then

  mkdir manifests && cp ${PUPPET_TPL_DIR}/manifests/liferay.pp manifests/default.pp || exit 1
  cp -r ${PUPPET_TPL_DIR}/modules/ . || exit 1

  sed -i "s/@@JAVA@@/${java}/"    modules/java/manifests/init.pp    || exit 1
  sed -i "s/@@AS@@/${as}/"        modules/liferay/manifests/init.pp || exit 1
  sed -i "s/@@LRVER@@/${lrver}/"  modules/liferay/manifests/init.pp || exit 1

  vagrant init -m ubuntu/trusty64 || exit 1
  #vagrant init -m $ticket $BOX_URL/ubuntu.box || exit 1

# If not tomcat or jboss, use puppet only for java installation and a box already prepared for the rest of the job
elif [[ $os == "linux" ]]; then

  mkdir manifests && cp ${PUPPET_TPL_DIR}/manifests/java.pp manifests/default.pp || exit 1
  mkdir modules   && cp -r ${PUPPET_TPL_DIR}/modules/java   modules/             || exit 1
  mkdir modules   && cp -r ${PUPPET_TPL_DIR}/modules/stdlib modules/             || exit 1

  sed -i "s/@@JAVA@@/${java}/"    modules/java/manifests/init.pp || exit 1

  vagrant init -m $ticket $BOX_URL/liferay-${lrver}-${as}-${os}.box || exit 1

# If windows, use an "out-of-the-box" box
elif [[ $os == "windows" ]]; then

  vagrant init -m $ticket $BOX_URL/liferay-${lrver}-${as}-${os}.box || exit 1

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

# Inform puppet the Patching Tool version to download
wget -q ${HTTP_SERVER}/private/ee/fix-packs/patching-tool/LATEST.txt -P /tmp || exit 1
patching_tool_version="$(cat /tmp/LATEST.txt)" || exit 1
sed -i "s/@@PT_VERSION@@/${patching-tool-version}/" modules/liferay/manifests/init.pp || exit 1

# Inform puppet what driver to install on Liferay
sed -i "s/@@DB@@/${db}/"       modules/liferay/manifests/init.pp || exit 1
sed -i "s/@@PATCH@@/${patch}/" modules/liferay/manifests/init.pp || exit 1

vagrant up || exit 1
#vagrant ssh -c "/home/liferay/liferay-${lrver}/patching-tool.sh download ${patch}" || exit 1
#vagrant ssh -c "/home/liferay/liferay-${lrver}/patching-tool.sh install ${patch}"  || exit 1

