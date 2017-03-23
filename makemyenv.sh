#!/bin/bash

set -e

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
      echo '                            default: <ubuntu>'
      echo
      echo '   -a <application-server>  Insert the Application Server for Liferay'
      echo '                            default: <tomcat>'
      echo
      echo '   -V <app-server-version>  Insert the Application Server version for Liferay'
      echo '                            default: <last available>'
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

while getopts 't:v:o:a:V:p:j:d:l:s:h' opt; do
  case $opt in
    t)
      if [[ $OPTARG =~ [a-z0-9]+-[0-9]+ ]]; then
        ticket=$OPTARG
      else
        echo "Error: Invalid ticket name: \"$OPTARG\""
        echo '  Please use a name like: "abc-123"'
        exit 1
      fi
    ;;
    v)
      case $OPTARG in 
        6110|6120|6130|6210|7010)
          lrver=$OPTARG
        ;;
        *)
          echo "Error: Liferay version not supported: \"$OPTARG\""
          echo '  Please use 6110, 6120, 6130, 6210 or 7010'
          exit 1
        ;;
      esac
    ;;
    o)
      case $OPTARG in
        ubuntu|centos|windows)
          os=$OPTARG
        ;;
        *)
          echo "Error: Operating System not supported: \"$OPTARG\""
          echo '  Please use ubuntu, centos or windows'
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
    V)
      if [[ $OPTARG =~ [0-9\.]+ ]]; then
          asver=$OPTARG
      else
          echo "Error: Application Server version not valid: \"$OPTARG\""
          echo '  Please use numbers and dots'
          exit 1
      fi
    ;;
    p)
      if [[ $OPTARG =~ (de|portal|hotfix)-[0-9]+-(6130|6210|7010) ]]; then
        patch=$OPTARG
      else
        echo "Error: Invalid patch name: \"$OPTARG\""
        echo '  Please insert a patch name like: "[de|portal|hotfix]-123-[6130|6210|7010]"'
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
        postgresql|mysql|mssql|oracle|db2|none)
          db=$OPTARG
        ;;
        *)
          echo "Error: Database not supported: \"$OPTARG\""
          echo '  Please use postgresql, mysql, mssql, oracle, db2 or none (hsqldb)'
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
: ${os:=ubuntu}
: ${as:=tomcat}
: ${patch:=}
: ${java:=6}
: ${db:=postgresql}
: ${ldap:=}
: ${sso:=}

if [[ $lrver != ${patch##*-} && -n $patch ]]; then
  echo "Error: The patch inserted \"${patch}\" doesn't match Liferay version \"${lrver}\""
  echo '  Please use a patch compatible with the Liferay version selected'
  exit 1
fi

# must be arrays
# insert versions in decreasing order
case $lrver in
  7010)
    tomcat_versions=('8.0.32')  
    jboss_versions=('eap-6.4')
    #websphere_versions=
    #weblogic_versions=
  ;;	  
  6210)
    tomcat_versions=('7.0.62' '7.0.42')
    jboss_versions=('7.1.1')
    #websphere_versions=
    #weblogic_versions=
  ;;
  6130)
    tomcat_versions=('7.0.40')
    jboss_versions=('7.1.1')
    #websphere_versions=
    #weblogic_versions=
  ;;
  6120)
    tomcat_versions=('7.0.27')
    jboss_versions=('7.1.1')
    #websphere_versions=
    #weblogic_versions=
  ;;
  6110)
    tomcat_versions=('7.0.25')
    jboss_versions=('7.0.2')
    #websphere_versions=
    #weblogic_versions=
  ;;
esac

case $as in
  tomcat)
    if [[ -z $asver ]]; then
      asver=${tomcat_versions[0]}
    elif ! [[ ${tomcat_versions[*]} =~ (^|[[:space:]])"$asver"($|[[:space:]]) ]]; then
      echo "Error: $asver is not a valid tomcat version"
      echo "  Please use one of ${tomcat_versions[@]}"
      exit 1
    fi
  ;;
  jboss)
    if [[ -z $asver ]]; then
      asver=${jboss_versions[0]}
    elif ! [[ ${jboss_versions[*]} =~ (^|[[:space:]])"$asver"($|[[:space:]]) ]]; then
      echo "Error: $asver is not a valid jboss version"
      echo "  Please use one of ${jboss_versions[@]}"
      exit 1
    fi
  ;;
  websphere)
    if [[ -z $asver ]]; then
      asver=${websphere_versions[0]}
    elif ! [[ ${websphere_versions[*]} =~ (^|[[:space:]])"$asver"($|[[:space:]]) ]]; then
      echo "Error: $asver is not a valid websphere version"
      echo "  Please use one of ${websphere_versions[@]}"
      exit 1
    fi
  ;;
  weblogic)
    if [[ -z $asver ]]; then
      asver=${weblogic_versions[0]}
    elif ! [[ ${weblogic_versions[*]} =~ (^|[[:space:]])"$asver"($|[[:space:]]) ]]; then
      echo "Error: $asver is not a valid weblogic version"
      echo "  Please use one of ${weblogic_versions[@]}"
      exit 1
    fi
  ;;
esac

USER_HOME="/home/vagrant"
TICKETS_DIR="${USER_HOME}/tickets"
PROPS_TPL_DIR="${USER_HOME}/props-templates"
PUPPET_TPL_DIR="${USER_HOME}/puppet-templates"
DB_DRIVERS_DIR="${USER_HOME}/db-drivers"

HTTP_SERVER='http://192.168.110.251'
BOX_URL="${HTTP_SERVER}/vagrant-boxes"
DB_SERVER='192.168.110.120'
DB_ADM='admin'
DB_PASS='4c2b2cdcbe7f369d3d01a8f3c5202e37'

# Prepare vagrant user directory
cd $TICKETS_DIR 
mkdir $ticket
cd $ticket 

dbuser=${ticket//-/}
dbpass=${ticket//-/}
dbname=${ticket//-/}

# Create DB for the new environment
case $db in
  postgresql)

# better not indent heredocs
PGPASSWORD=$DB_PASS psql -h $DB_SERVER -U $DB_ADM postgres << END
CREATE USER ${dbuser} WITH PASSWORD '${dbpass}';
CREATE DATABASE ${dbname} OWNER ${dbuser};
END

  ;;
  mysql)

mysql -h $DB_SERVER -u $DB_ADM -p${DB_PASS} << END
CREATE DATABASE ${dbname};
GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'%' IDENTIFIED BY '${dbpass}';
END

  ;;
  mssql)
    DB_ADM='sa'
    DB_PASS='password'
    dbuser='sa'
    dbpass='password'

isql MSSQLServer $DB_ADM $DB_PASS -b << END
CREATE DATABASE ${dbname}
END

  ;;
  oracle)

    DB_ADM='SYSTEM'
    DB_PASS='password'

sqlplus ${DB_ADM}/${DB_PASS}@${DB_SERVER}/ORCL << END
ALTER SESSION SET "_ORACLE_SCRIPT"=true;
CREATE USER ${dbuser} IDENTIFIED BY ${dbpass} DEFAULT TABLESPACE USERS;
GRANT "RESOURCE" TO ${dbuser};
GRANT "CONNECT" TO ${dbuser};
GRANT UNLIMITED TABLESPACE TO ${dbuser};

GRANT READ ON DIRECTORY IMPDP TO ${dbuser};
GRANT WRITE ON DIRECTORY IMPDP TO ${dbuser};

GRANT IMP_FULL_DATABASE TO ${dbuser};
GRANT IMPORT FULL DATABASE TO ${dbuser};
END

  ;;
  db2)
    DB_ADM='liferay'
    DB_PASS='R3m3mb3r321'
    dbuser='liferay'
    dbpass='R3m3mb3r321'
    echo 'Creating DB2 database, please wait...'
    sshpass -p ${DB_PASS} ssh ${DB_ADM}@${DB_SERVER} "db2 \"create db $dbname pagesize 8 k\""
  ;;
  none)
    echo "Using HSQLDB"
  ;;
esac

# Prepare user's portal-ext.properties
cat $PROPS_TPL_DIR/defaults-portal-ext.properties >> portal-ext.properties
[[ ! ${db} == 'none' ]] && cat ${PROPS_TPL_DIR}/db/${db}-portal-ext.properties >> portal-ext.properties 
if [[ -n $ldap ]]; then
  cat ${PROPS_TPL_DIR}/ldap/${ldap}-portal-ext.properties >> portal-ext.properties 
fi
if [[ -n $sso ]]; then
  cat ${PROPS_TPL_DIR}/sso/${sso}-portal-ext.properties >> portal-ext.properties 
fi

sed -i "s/@@DBSERVER@@/${DB_SERVER}/"  portal-ext.properties 
sed -i "s/@@DBNAME@@/${dbname}/"       portal-ext.properties 
sed -i "s/@@DBUSER@@/${dbuser}/"       portal-ext.properties 
sed -i "s/@@DBPASS@@/${dbpass}/"       portal-ext.properties 

# If Linux with tomcat or jboss let's use puppet to install Liferay
if [[ $os =~ (ubuntu|centos) && $as =~ (tomcat|jboss) ]]; then

  mkdir manifests && cp ${PUPPET_TPL_DIR}/manifests/liferay.pp manifests/default.pp 
  cp -r ${PUPPET_TPL_DIR}/modules/ . 

  sed -i "s/@@JAVA@@/${java}/"    modules/java/manifests/init.pp    
  sed -i "s/@@AS@@/${as}/"        modules/liferay/manifests/init.pp 
  sed -i "s/@@ASVER@@/${asver}/"  modules/liferay/manifests/init.pp 
  sed -i "s/@@LRVER@@/${lrver}/"  modules/liferay/manifests/init.pp 

  case $os in
    "ubuntu")
      vagrant init -m $ticket "$BOX_URL/trusty-server-cloudimg-amd64-vagrant-disk1.box" 
    ;;
    "centos")
      vagrant init -m $ticket "$BOX_URL/centos-7.2.box" 
    ;;
  esac

# If not tomcat or jboss, use puppet only for java installation and a box already prepared for the rest of the job
elif [[ $os =~ (ubuntu|centos) ]]; then

  mkdir manifests && cp ${PUPPET_TPL_DIR}/manifests/java.pp manifests/default.pp 
  mkdir modules   && cp -r ${PUPPET_TPL_DIR}/modules/java   modules/             
  mkdir modules   && cp -r ${PUPPET_TPL_DIR}/modules/stdlib modules/             

  sed -i "s/@@JAVA@@/${java}/"    modules/java/manifests/init.pp 

  vagrant init -m $ticket $BOX_URL/liferay-${lrver}-${as}-${os}.box 

# If windows, use an "out-of-the-box" box
elif [[ $os == "windows" ]]; then

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

# Inform puppet the Patching Tool version to download
mkdir /tmp/${ticket}
if [[ $lrver == '7010' ]]; then
  wget -q ${HTTP_SERVER}/private/ee/fix-packs/patching-tool/LATEST-2.0.txt -P /tmp/${ticket}/
  patching_tool_version="$(cat /tmp/${ticket}/LATEST-2.0.txt)"
else
  wget -q ${HTTP_SERVER}/private/ee/fix-packs/patching-tool/LATEST.txt -P /tmp/${ticket}/
  patching_tool_version="$(cat /tmp/${ticket}/LATEST.txt)"
fi
rm -rf /tmp/${ticket}

sed -i "s/@@PTVER@@/${patching_tool_version}/" modules/liferay/manifests/init.pp 

# Inform puppet what driver and what patch to install on Liferay
sed -i "s/@@DB@@/${db}/"       modules/liferay/manifests/init.pp 
sed -i "s/@@PATCH@@/${patch}/" modules/liferay/manifests/init.pp 

vagrant up 
#vagrant ssh -c "/home/liferay/liferay-${lrver}/patching-tool.sh download ${patch}" 
#vagrant ssh -c "/home/liferay/liferay-${lrver}/patching-tool.sh install ${patch}"  

