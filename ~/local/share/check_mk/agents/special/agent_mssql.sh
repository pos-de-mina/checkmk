#!/bin/bash
# 
# https://github.com/pos-de-mina/check_mk
# 
# Campatible with original Agent base:
#   - https://github.com/Checkmk/checkmk/tree/master/agents/windows/plugins/mssql.vbs
# 
# References:
#   - https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql
#   - https://learn.microsoft.com/pt-br/sql/t-sql/functions/isnull-transact-sql
# 
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# Global variables
# -----------------------------------------------------------------------------
EPOCH_DATE=$(date +%s)

MSSQL_SERVER=$1
MSSQL_INSTANCE=$2
MSSQL_PORT=$3
MSSQL_USR=$4
MSSQL_PWD=$5
declare -A MSSQL_SECTIONS=$6
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
printf '<<<check_mk>>>\nVersion: 1.0\nAgentOS: MSSQL Agentless\n'

# verify connection to database
printf "<<<error>>>\n"
sqlcmd \
    -S "tcp:${MSSQL_SERVER}\\${MSSQL_INSTANCE},${MSSQL_PORT}" \
    -U "${MSSQL_USR}" -P "${MSSQL_PWD}" \
    -s '|' -w 512 -W -b -h-1 -E \
    -Q "set nocount on; select getdate(), 'No error';"
if [ $? -ne 0 ]; then
    exit 2
fi

# Create an inventory of databases
readarray -t MSSQL_DATABASES < <(sqlcmd \
    -S "tcp:${MSSQL_SERVER}\\${MSSQL_INSTANCE},${MSSQL_PORT}" \
    -U "${MSSQL_USR}" -P "${MSSQL_PWD}" \
    -s '|' -w 512 -W -b -h-1 -E \
    -Q "set nocount on; select name from sys.databases")

# Print the elements of the array
# for db in "${MSSQL_DATABASES[@]}"; do
#   echo "$db"
# done
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# Parameters:
#   1: service name
#   2: Cache Age in seconds
checkmk_service() {
# -----------------------------------------------------------------------------
    printf "<<<${1}:sep(124):cached(${EPOCH_DATE},${2})>>>"
}
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# Parameters:
#   1: service name
#   2: database name. for instance use msdb!
#   - https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility
mssql_query() {
# -----------------------------------------------------------------------------
    local MSSQL_SECTION=$1
    local MSSQL_DB=$2

    # sqlcmd -S 'localhost,1433' -U sa -P 'yourStrong(!)Password' -d 'tempdb' -Q 'set nocount on;select getdate()'
    # sqlcmd -S .\$instance -d $database -E -W -w 1024 -i $_ -s "|" -h-1 -o "C:\ProgramData\checkmk\agent\spool\$($_.BaseName).$($instance).$($database).log"

    sqlcmd \
        -S "tcp:${MSSQL_SERVER}\\${MSSQL_INSTANCE},${MSSQL_PORT}" \
        -U "${MSSQL_USR}" -P "${MSSQL_PWD}" \
        -s '|' -w 512 -W -b -h-1 -E \
        -d ${MSSQL_DB}
        -i mssql.${MSSQL_SECTION}.sql
        -o ~/tmp/mssql.${MSSQL_SECTION}.${MSSQL_SERVER}.${MSSQL_INSTANCE}.cache
}
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# Parameters:
#   1: service name
#   2: database name
#   - https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility
# -----------------------------------------------------------------------------



ls -1 ~/.../mssql.instance.*.sql | while read mssql_instance_file; do
    checkmk_service 
done

ls -1 ~/.../mssql.database.*.sql | while read mssql_database_file; do
    checkmk_service 
done

# -----------------------------------------------------------------------------



# Path to scripts
MSSQL_AGENT_HOME=~/local/share/check_mk/agents/special/


##############################################################################

#######################################
# Query Oracle via SQL Plus
# P A R A M S
#   - $1: Section to run
#   - $2: Section Age
# O U T P U T
#   - return the output from 
#######################################
mssql_query () {
  MSSQL_SECTION=$1
  MSSQL_SECTION_AGE=$2
  MSSQL_FILE_AGE=0
  MSSQL_FILE="/tmp/mssql_${MSSQL_HOST}_${MSSQL_SID}_${MSSQL_SECTION}.log"
  MSSQL_FILE2="${MSSQL_FILE}.new"

  # create files if doesn't exist
  if [[ ! -f $MSSQL_FILE ]]; then
    touch $MSSQL_FILE
  fi
  if [[ ! -f $MSSQL_FILE2 ]]; then
    touch $MSSQL_FILE2
  fi

  # verify file age
  MSSQL_FILE_AGE=$(expr $(date +%s) - $(stat -c %Y ${MSSQL_FILE2}))
  MSSQL_FILE_AGE=$(( MSSQL_FILE_AGE / 60 ))
  # verify if file are empty
  if [[ $(wc -c $MSSQL_FILE2 | awk '{print $1}') -gt 1 ]]; then
    cp $MSSQL_FILE2 $MSSQL_FILE
  fi

  echo "<<<mssql_${MSSQL_SECTION}:sep(124):cached($(date +%s),$(($MSSQL_SECTION_AGE * 60)))>>>"
  cat ${MSSQL_FILE}

  echo "$(date +%s) | $MSSQL_SECTION $MSSQL_SECTION_AGE $MSSQL_FILE $MSSQL_FILE_AGE" >> /tmp/mssql_agent.${USER}.log

  # run sqlplus asynchronous
  if [[ $MSSQL_FILE_AGE -gt $MSSQL_SECTION_AGE || $MSSQL_FILE_AGE -eq 0 ]]; then
    echo "$(date +%s) | Run Assync $MSSQL_SECTION" >> ~/tmp/mssql_agent.${USER}.log
    cat $MSSQL_AGENT_HOME/mssql_$MSSQL_SECTION.sql | sqlplus -S $MSSQL_USR/$MSSQL_PWD@$MSSQL_SID > $MSSQL_FILE2 2>>/tmp/mssql_agent.${USER}.error.log &
  fi
}

##############################################################################

#######################################
# Check_MK Agent Protocol Header

#######################################
# Dump all Sections 
# /omd/agent_oracle.sh 'apexa2ip-scan.besp.dsp.gbes' DAPP7 nagios N4gi1os2k19 (['version']=3600 ['processes']=60 ['logswitches']=60 ['locks']=60 ['performance']=60 ['dataguard_stats']=60 ['asm_diskgroup']=60 ['longactivesessions']=60 ['recovery_status']=60 ['sessions']=60 ['resumable']=60 ['rman']=60 ['tablespaces']=60 ['recovery_area']=60 ['undostat']=60 ['jobs']=60 ['ts_quotas']=60 ['instance']=60)

for section in "${!MSSQL_SECTIONS[@]}"; do
  # verify if section can be called. Zero means this sections can't call.
  if [ ${MSSQL_SECTIONS[$section]} -gt 0 ]; then
    printf "<<<mssql_${section}:sep(124):cached(${EPOCH_DATE},${2})>>>"
    mssql_query $section ${MSSQL_SECTIONS[$section]};
  fi
done
