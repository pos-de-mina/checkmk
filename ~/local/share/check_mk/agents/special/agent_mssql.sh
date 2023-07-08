#!/bin/bash
# 
# https://github.com/pos-de-mina/check_mk
# 
# Campatible with original Agent base:
#   - https://github.com/Checkmk/checkmk/tree/master/agents/windows/plugins/mssql.vbs
# 
# References:
#   - https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility
# 
# Parameters:
#   - $1: MSSQL Server/IP address
#   - $2: MSSQL Instance name
#   - $3: MSSQL Instance port
#   - $4: MSSQL User (database user only)
#   - $5: MSSQL Password
#   - $6: an array with session and cache age in minutes format (['session_1']=3600 ['session_n']=60)
# 
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# Global variables
EPOCH_DATE=$(date +%s)

# Parameters
MSSQL_SERVER=$1
MSSQL_INSTANCE=$2
MSSQL_PORT=$3
MSSQL_USR=$4
MSSQL_PWD=$5
declare -A MSSQL_SECTIONS=$6

# Path to scripts
MSSQL_AGENT_HOME=~/local/share/check_mk/agents/special/
MSSQL_DB_INVENTORY=~/tmp/mssql.${MSSQL_SERVER}.${MSSQL_INSTANCE}.databases.inventory
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# References:
#   - https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility
# Parameters:
#   1: .sql file
#   2: database name. default master!
mssql_query() {
    local MSSQL_FILE=$1
    local MSSQL_DB=$2

    sqlcmd \
        -S "tcp:${MSSQL_SERVER}\\${MSSQL_INSTANCE},${MSSQL_PORT}" \
        -U "${MSSQL_USR}" -P "${MSSQL_PWD}" \
        -s '|' -w 512 -W -b -h-1 -E \
        -d ${MSSQL_DB}
        -i ${MSSQL_FILE}
}

# -----------------------------------------------------------------------------
# Description:
#   Get file age in minutes based on modified date
# Parameters:
#   $1: THe file to check
# Returns:
#   file age in minutes
get_file_age_in_minutes() {
  # file to check
  local file_path="$1"
  # Get the current timestamp in seconds since the epoch
  local current_time=$(date +%s)
  # Get the file's modification timestamp in seconds since the epoch
  local file_mtime=$(stat -c %Y "${file_path}")
  # Calculate the age of the file in minutes
  local age_minutes=$(( (current_time - file_mtime) / 60 ))

  echo "${age_minutes}"
}

# -----------------------------------------------------------------------------
#  Main body

# print header for checkmk agent format 
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
sqlcmd \
    -S "tcp:${MSSQL_SERVER}\\${MSSQL_INSTANCE},${MSSQL_PORT}" \
    -U "${MSSQL_USR}" -P "${MSSQL_PWD}" \
    -s '|' -w 512 -W -b -h-1 -E \
    -Q "set nocount on; select name from sys.databases;" \
    -o ${MSSQL_DB_INVENTORY}

# list all Sections 
for section in "${!MSSQL_SECTIONS[@]}"; do
    # get section age in minutes
    # ! section age if 0 means real time not assyncronous
    section_age=${MSSQL_SECTIONS[$section]}
    section_file_cache="~/tmp/mssql.${MSSQL_SERVER}.${MSSQL_INSTANCE}.${section}.cache"
    section_file_cache_age=0
    section_file_sql=$(ls -1 ~/tmp/mssql.*.${section}.sql)

    # check if file not exists, create file
    if [ ! -f "${section_file_cache}" ]; then
        touch "${section_file_cache}"
        # section_file_cache_age=0
    else
        # get file age
        section_file_cache_age=$(get_file_age_in_minutes "${section_file_cache}")
    fi

    # compare file age with section age
    if (( section_age > section_file_cache_age )) && (( section_age > 0 )); then
        # dump assync collection of file
        cat ${section_file_cache}
    fi

    # print section
    printf "<<<mssql_${section}:sep(124):cached(${EPOCH_DATE},${section_age})>>>" > ${section_file_cache}

    case "$section_file_sql" in
        *".instance."*)
            # Syncronous
            if (( section_age = 0 )); then
                mssql_query $section_file_sql 'master' >> ${section_file_cache}
                cat ${section_file_cache}
            # Assyncronous
            else
                mssql_query $section_file_sql 'master' >> ${section_file_cache} &
            fi
            ;;
        *".database."*)
            # Syncronous
            if (( section_age = 0 )); then
                # get information for all databases
                cat ${MSSQL_DB_INVENTORY} | while read mssql_db; do
                    mssql_query $section_file_sql $mssql_db >> ${section_file_cache};
                done
                cat ${section_file_cache}
            # Assyncronous
            else
                # get information for all databases
                cat ${MSSQL_DB_INVENTORY} | while read mssql_db; do
                    mssql_query $section_file_sql $mssql_db >> ${section_file_cache} &;
                done
            fi
            ;;
    esac
done
