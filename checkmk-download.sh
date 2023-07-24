#!/bin/bash
#
# Referneces:
#   - https://download.checkmk.com/stable_downloads.json
#   - https://forum.checkmk.com/t/how-to-download-latest-version-of-mk-programatically/31113
#   - https://thl-cmk.hopto.org/gitlab/checkmk/various/checkmk_update/
# 


# Parameters:
#   - $1: checkmk user for download packages
#   - $2: checkmk password
#   - $3: edition
CMK_USR=$1
CMK_PWD=$2
CMK_EDITION=$3


# files
CMK_JSON=cmk.$?.json
CMK_FILES=cmk.$?.files

# get json
echo 'DBG: get json'
curl --silent https://download.checkmk.com/stable_downloads.json > $CMK_JSON

# Editions:
#   - cee: Enterprise
#   - cre: RAW/Open Source
#   - cme: MSP/Managed Services
#   - cce: Cloud
#   - cfe: Free
echo 'DBG: create an list of files based on edition '$CMK_EDITION
jq -r ".checkmk[].editions.${CMK_EDITION}[][0]" $CMK_JSON | \
  grep -E 'deb|rpm|docker' >> $CMK_FILES

#
echo 'DBG: get all files based on version'
jq -r '.checkmk[].version' $CMK_JSON | \
  while read version; do
    grep "${version}" $CMK_FILES | \
      while read file; do
        if [ ! -f ${file} ]; then
          echo 'DBG: version: '$version'; file: '$file';'
          wget --user "$CMK_USR" --password "$CMK_PWD" "https://download.checkmk.com/checkmk/${version}/$file"
        fi
      done
  done

# clean files
rm -f cmk.$?.*
