#/bin/python
#
# Plugin to check LDAP Group Members Changes
#
# S E T U P
#   chmod +x /omd/check_ldapusergroup.py
#   ln -s /omd/check_ldapuser.py /omd/versions/default/lib/nagios/plugins/check_ldapusergroup
#
# R E F S
#   - https://www.ietf.org/rfc/rfc2255.txt
#
# U S A G E
#     - python check_ldapuser <server> <user> <password> <user2search> <base ldap search>
#         . server      | fqdn for ldap server; Ex. ldap://ldapserver.domain.com:389
#         . user        | user for validating accounts
#         . password    | password for user
#         . Base DN     | LDAP base search; Ex. DC=domain,DC=com
#         . Search      | user to search; (&(objectClass=group)(sAMAccountName=user01))
#         . Age Warn    | Age in Days for Warning
#         . Age Crit    | Age in Days for Warning
#
# Copyright (c) 2020-04-28 Antonio Pos-de-Mina

import ldap, sys, datetime, os


# LDAP Server, User, Password
_params = {
	'ldap' : {
		'url' : "ldap://%s:389/" % (sys.argv[1]),
		'user' : sys.argv[2],
		'pwd' : sys.argv[3],

		'BaseDN' : sys.argv[4],
		'Search' : "(&(objectClass=group)(sAMAccountName=%s))" % (sys.argv[5]),
		'Attributes' : ['sAMAccountName','whenChanged','member']
	},
	'Age' : {
		'Warn' : int(sys.argv[6]),
		'Crit' : int(sys.argv[7])
	}
}


ldap_group = {
	'Name' : sys.argv[4],
	'Change' : datetime.datetime.today(),
	'Members' : None
}

LDAP_FILE = "/tmp/ldap-group-members.%s.raw" % ldap_group['Name']

# -------------------------------------
# Load Cache file

# open files
if (os.path.exists (LDAP_FILE)):
	ldap_group = eval(open(LDAP_FILE).read())

# -------------------------------------
# Get infromation from LDAP

ldap_group_tmp = {
	'Name' : sys.argv[4],
	'Change' : datetime.datetime.today(),
	'Members' : None
}

try:
	# open LDAP connection
	l = ldap.initialize (_params['ldap']['url'])
	l.protocol_version = ldap.VERSION3
	l.set_option(ldap.OPT_REFERRALS, 0)
	bind = l.simple_bind_s (_params['ldap']['user'], _params['ldap']['pwd'])

	# LDAP search
	result = l.search_s (_params['ldap']['BaseDN'], ldap.SCOPE_SUBTREE, _params['ldap']['Search'], _params['ldap']['Attributes'])
	if (result != None):
		for r in result:
			if (r[0] != None):
				ldap_group_tmp['Change'] = datetime.datetime.strptime (r[1]['whenChanged'][0][:12], '%Y%m%d%H%M')
				ldap_group_tmp['Members'] = r[1]['member']
	else:
		print "Group %s not found!" % (ldap_search)
		exit(3)	
finally:
	l.unbind()


# -------------------------------------
# Compare members

new_members = []
if (ldap_group['Members'] == None):
	ldap_group = ldap_group_tmp.copy()
elif (ldap_group['Change'] != ldap_group_tmp['Change']):
	ldap_group['Change'] = ldap_group_tmp['Change']
	for m in ldap_group_tmp['Members']:
		if (m not in ldap_group['Members']):
			new_members.append (m)

# dump file
open(LDAP_FILE,"w").write ( str(ldap_group) )


# -------------------------------------
# Output service state

ldap_change_age = (datetime.datetime.now() - ldap_group['Change']).days
print "Group Change Age [days]: %s; Last Group Change: %s; Members: %s\n%s" % (ldap_change_age, ldap_group['Change'], len(new_members), new_members)
if (ldap_change_age < _params['Age']['Crit']):
	exit (2)
elif (ldap_change_age < _params['Age']['Warn']):
	exit (1)
exit (0)
