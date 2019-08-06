#/bin/python
#
# Plugin to check Account status via LDAP
#
# S E T U P
#   ln -s /omd/tools/jq /omd/sites/*/jq
#   chmod +x /omd/check_ldapuser.py
#   ln -s /omd/check_ldapuser.py /omd/versions/default/lib/nagios/plugins/check_ldapuser
#
# R E F S
#   - 
#
# U S A G E
#     - python check_ldapuser <server> <user> <password> <user2search> <base ldap search>
#         . server      | fqdn for ldap server; Ex. ldap://ldapserver.domain.com
#         . user        | user for validating accounts
#         . password    | password for user
#         . user2search | user to search; (&(objectClass=user)(sAMAccountName=user01))
#         . ldap search | LDAP base search; Ex. DC=domain,DC=com
#
# Copyright (c) 2019-07-10 Antonio Pos-de-Mina

import ldap
import sys

# Parameters
ldapServer = sys.argv[1]
bindUser   = sys.argv[2]
bindPwd    = sys.argv[3]
userSearch = sys.argv[4]
baseSearch = sys.argv[5]


l = ldap.initialize("ldap://%s" % (ldapServer))
try:
    l.protocol_version = ldap.VERSION3
    l.set_option(ldap.OPT_REFERRALS, 0)

    bind = l.simple_bind_s(bindUser, bindPwd)

    base = baseSearch
    criteria = "(&(objectClass=user)(sAMAccountName=%s))" % (userSearch)
    attributes = ['*']
    result = l.search_s(base, ldap.SCOPE_SUBTREE, criteria, attributes)

    if int(result[0][1]['lockoutTime'][0]) == 0:
        print 'User %s not locked!' % (result[0][0])
        exit(0)
    else:
        print 'User %s locked!' % (result[0][0])
        exit(2)
finally:
    l.unbind()
