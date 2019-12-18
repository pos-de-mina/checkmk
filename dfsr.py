#!/usr/bin/python
# -*- encoding: utf-8; py-indent-offset: 4 -*-
#

def inventory_dfsr(info):
    return [ ( x[0], 'None' ) for x in info  ]

def check_dfsr(item, _unused, info):
    for line in info:
        if line[0] != item:
            continue
        mystate = line[1]
        mylistener = line[0]

        if mystate in [ 'In Error' ]:
            return (2, 'FAIL - ' + "".join(item) + " is " + "".join(mystate))
        if mystate in [ 'Initialized', 'Auto Recovery', 'Uninitialized', 'Initial Sync' ]:
            return (1, 'WARNING - ' + "".join(item) + " is " + "".join(mystate))
        if mystate in [ 'Normal' ]:
            return (0, 'OK - ' + "".join(item) + " is " + "".join(mystate))

        return (3, "UNKNWON - % line")

check_info["dfsr"] = {
    'check_function':       check_dfsr,
    'inventory_function':   inventory_dfsr,
    'service_description':  'DFSR %s Status',
    'has_perfdata':         False,
}
