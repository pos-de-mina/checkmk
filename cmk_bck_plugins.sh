#!/bin/bash
# Backup Check_MK Plug-ins from unix (linux,solaris,hpux,aix) OS to /tmp/cmk_hosts/
#
# ! Require Shared Key from hosts
#
# (c) 2019-09 António Pós-de-Mina

cmk_home=/tmp/cmk_hosts/

# create home directory
[ ! -d $cmk_home ] && mkdir -p $cmk_home

while read host
do
    # create host directory
    [ ! -d ${cmk_home}${host}/ ] && mkdir ${cmk_home}${host}/

    # copy all plugins
    scp $host:/usr/lib/check_mk_agent/plugins/* ${cmk_home}${host}/

    # copy all 'local' plugins
    scp $host:/usr/lib/check_mk_agent/local/* ${cmk_home}${host}/

done < ${cmk_home}cmk_hosts.txt
