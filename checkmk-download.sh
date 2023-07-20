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
# 
# 

CMK_USR=$1
CMK_PWD=$2

# 
curl --silent https://download.checkmk.com/stable_downloads.json | \
  jq -r '.checkmk[].editions.cee[][0]' | 
  grep -E 'deb|rpm|docker' > cmk.files

rm -f cmk.url
curl --silent https://download.checkmk.com/stable_downloads.json | \
  jq -r '.checkmk[].version' | \
  while read version; do
    # 
    grep "${version}" cmk.files | \
      while read a; do
        echo "https://download.checkmk.com/checkmk/${version}/$a" >> cmk.url
      done
  done

cat cmk.url | \
  while read url; do
    wget --user "$CMK_USR" --password "$CMK_PWD" "${url}"
  done

# debug
# cat cmk.url
