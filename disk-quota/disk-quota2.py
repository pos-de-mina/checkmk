#!/usr/bin/env python3
# -*- encoding: utf-8; py-indent-offset: 4 -*-

# Client output: Quota Path, Quota Usage [KB], Quota Size [KB], Quota Type (Hard|Soft)
# <<<disk_quota:sep(9)>>>
# X:\Container_BalcUsers\USER_P01478\P01478 1 5242880 0 hard
# X:\Container_BalcUsers\USER_P01640 7 5242880 0 hard
# X:\Container_BalcUsers\USER_P01793\P01793 1 5242880 0 hard
# X:\Container_BalcUsers\USER_P01643\P01643 1 5242880 0 hard
# X:\Container_BalcUsers\USER_P01644\P01644 1 5242880 0 hard

# https://github.com/pos-de-mina/

from .agent_based_api.v1 import *

def discover_disk_quota(section):
    for v in section:
        yield Service(item=v[0].replace('\\', '/'))

def check_disk_quota(item, params, section):
    for quota_path, quota_used_mb, quota_size_mb, quota_type in section:
        quota_path = quota_path.replace('\\', '/')
        if quota_path == item:
            warn, crit = params['usage_percentage']

            # process metrics
            if quota_size_mb:
                quota_percentage = float(quota_used_mb) * 100.0 / float(quota_size_mb)
            else:
                quota_percentage = 0.0
            quota_used_mb = float(quota_used_mb) * 1.0
            quota_used_gb = float(quota_used_mb) / 1024.0
            quota_size_gb = float(quota_size_mb) / 1024.0
            yield Metric("usage_percentage", quota_percentage, levels=(warn, crit), boundaries=(0, 100))
            yield Metric("usage_gb", quota_used_gb, boundaries=(0, quota_size_gb))

            # process service state
            if quota_percentage >= crit:
                yield Result(state=State.CRIT, summary=f"Percentage: {quota_percentage:.1f}% {warn}%/{warn}%) (!!), Usage: ({quota_used_gb:.2f}/{quota_size_gb:.1f}GB), Type: {quota_type}")
            elif quota_percentage >= warn:
                yield Result(state=State.WARN, summary=f"Percentage: {quota_percentage:.1f}% {warn}%/{warn}%) (!), Usage: ({quota_used_gb:.2f}/{quota_size_gb:.1f}GB), Type: {quota_type}")
            yield Result(state=State.OK, summary=f"Percentage: {quota_percentage:.1f}%, Usage: ({quota_used_gb:.2f}/{quota_size_gb:.1f}GB), Type: {quota_type}")
            return
    yield Result(state=State.UNKNOWN, summary='Item not found')

register.check_plugin(
    name='disk_quota',
    service_name='Disk Quota %s',
    discovery_function=discover_disk_quota,
    check_function=check_disk_quota,
    check_default_parameters = {"usage_percentage": (80, 90)},
)
