#!/usr/bin/python
# -*- encoding: utf-8; py-indent-offset: 4 -*-
# 
# located at /omd/sites/default/share/check_mk/checks
#
# Client output: Quota Path, Quota Usage [KB], Quota Size [KB], Quota Type (Hard|Soft)
# 
# <<<disk_quota:sep(9)>>>
# X:\share1\USER_U1\U1 1 5242880 0 hard
# X:\share1\USER_U2 7 5242880 0 hard
# X:\share1\USER_U3\U3 1 5242880 0 hard
# X:\share1\USER_U4\U4 1 5242880 0 hard
# X:\share1\USER_U5\U5 1 5242880 0 hard
# 

disk_quota_default_levels = {
        "usage" : (80,90)
}

def inventory_disk_quota(info):
    return [ ( x[0].replace('\\', '/'), 'disk_quota_default_levels' ) for x in info  ]

def check_disk_quota(item, params, info):

    perfdata = []
    infos = []
    status = 0
    this_time = time.time()
    for quota_path,quota_used_mb,quota_size_mb,quota_type in info:

        quota_path = quota_path.replace('\\', '/') # Windows \ is replaced with /
        if quota_path != item:
               continue

        warn, crit = params['usage']

        if quota_size_mb:
            quota_percentage = float(quota_used_mb) * 100.0 / float(quota_size_mb)
        else:
            quota_percentage = 0.0

        quota_used_mb = float(quota_used_mb) * 1.0
        rate_mb = get_rate("dq|%s|used_mb" % quota_path, this_time, quota_used_mb, True)
        rate_percentage = get_rate("dq|%s|used_pct" % quota_path, this_time, quota_percentage, True)

        quota_used_gb = float(quota_used_mb) / 1024.0
        quota_size_gb = float(quota_size_mb) / 1024.0
        infos.append("%.1f%% usage (%.2f of %.1f GB); type: %s" % (quota_percentage,quota_used_gb,quota_size_gb,quota_type))

        perfdata.append(( "quota MB",  quota_used_mb ))
        perfdata.append(( "quota %",  quota_percentage, warn, crit ))

        if quota_percentage >= crit:
            status = 2
        else:
            if quota_percentage >= warn:
                status = 1

        return (status, ", ".join(infos) , perfdata)


check_info['disk_quota'] = {
    "check_function"          : check_disk_quota,
    "inventory_function"      : inventory_disk_quota,
    "service_description"     : "Disk Quota %s",
    "has_perfdata"            : True,
}
