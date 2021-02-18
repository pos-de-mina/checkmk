#!/usr/bin/python
# -*- encoding: utf-8; py-indent-offset: 4 -*-
#
#
# Output example :
# <<<mssql_identity:sep(124)>>>
# mssql_instance|database|schema|table|column|cur_identity_value|max_identity_value
#


factory_settings["mssql_identity_default_levels"] = {
    "levels" : (80, 90),
}

def inventory_mssql_identity(info):
    inventory = []
    for line in info:
        if len(line) > 1:
            inventory.append((line[0], 'mssql_identity_default_levels'))
    return inventory

def check_mssql_identity(item, params, info):
    for line in info:
        srv_name, cur_identity_value, max_identity_value = line
        srv = line[0]
        if srv != item:
            continue
        
        warn, crit = params["levels"]
        perfdata = []
        if max_identity_value.isnumeric():
            max_identity_value = int(max_identity_value)
        else:
            max_identity_value = 2147483647
        cur_identity_value = int(cur_identity_value)
        identity_percentage = cur_identity_value / max_identity_value * 100.0
        
        perfdata.append(("Percentage", identity_percentage, warn, crit, 0, 100))
        perfdata.append(("Identity", cur_identity_value, '', '', 0, max_identity_value))

        if identity_percentage >= crit:
            return 2, 'Identity: %d; Max Identity: %d; Percentage: %d%% (warn/crit at %d/%d)' % (cur_identity_value, max_identity_value, identity_percentage, warn, crit), perfdata
        elif identity_percentage >= warn:
            return 1, 'Identity: %d; Max Identity: %d; Percentage: %d%% (warn/crit at %d/%d)' % (cur_identity_value, max_identity_value, identity_percentage, warn, crit), perfdata
        else:
            return 0, 'Identity: %d; Max Identity: %d; Percentage: %d%%' % (cur_identity_value, max_identity_value, identity_percentage), perfdata

check_info['mssql_identity'] = {
    'inventory_function'        : inventory_mssql_identity,
    'check_function'            : check_mssql_identity,
    'service_description'       : 'MSSQL %s Identity',
    'group'                     : 'mssql',
    'has_perfdata'              : True,
    'default_levels_variable'   : "mssql_identity_default_levels",
}