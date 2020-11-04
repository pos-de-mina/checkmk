#!/bin/bash
#
# Agent to Monitoring Prometheus via PromQL
#
# S E T U P
#   ln -s /omd/_custom/bin/jq-linux64 /bin/jq
#   chmod +x /omd/_custom/agents/agent_prometheus_v1.1.sh
#
# R E F
#   - https://github.com/stedolan/jq/releases
#   - https://github.com/prometheus/nagios_plugins/blob/master/check_prometheus_metric.sh
#   - https://stackoverflow.com/questions/48835035/average-memory-usage-query-prometheus
#
# Copyright (c) 2020-11 Antonio Pos-de-Mina
#

###############################################################################

#set -euo pipefail

export PROMETHEUS_SERVER=$1
export PROMETHEUS_USER=$2
export PROMETHEUS_PASSWORD=$3
export CMK_HOST_IP=$4

###############################################################################

function get_prometheus_ql() {

  curl -skG -u "${PROMETHEUS_USER}:${PROMETHEUS_PASSWORD}" \
    ${PROMETHEUS_SERVER}/api/v1/query \
    --data-urlencode "query=$1"

}

function get_prometheus_metric() {
  local promql=$1
  local jquery=$2

  curl -skG -u "${PROMETHEUS_USER}:${PROMETHEUS_PASSWORD}" \
    ${PROMETHEUS_SERVER}/api/v1/query \
    --data-urlencode "query=${promql}" | \
    jq -r $2
}

function check_prometheus_uptime () {
  local promql='node_time_seconds{hostname="'$PROMETHEUS_HOST'"} - node_boot_time_seconds{hostname="'$PROMETHEUS_HOST'"}'
  local jquery='.data.result[0].value[1]'

  printf "<<<uptime>>>\n%.0f\n" $(get_prometheus_metric "${promql}" "${jquery}")
}

function check_prometheus_cpu () {
  local jquery='.data.result[0].value[1]'
  
  printf "<<<cpu>>>\n"
  promql='node_load1{hostname="'$PROMETHEUS_HOST'"}'
  printf "%.2f "  $(get_prometheus_metric "${promql}" "${jquery}")
  promql='node_load5{hostname="'$PROMETHEUS_HOST'"}'
  printf "%.2f "  $(get_prometheus_metric "${promql}" "${jquery}")
  promql='node_load15{hostname="'$PROMETHEUS_HOST'"}'
  printf "%.2f "  $(get_prometheus_metric "${promql}" "${jquery}")
  printf "0/0 0\n"
}

function check_prometheus_memory () {

  local jquery='.data.result[0].value[1]'

  echo '<<<mem>>>'

  local promql='node_memory_MemTotal_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "MemTotal: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")
  local promql='node_memory_MemFree_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "MemFree: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")
  local promql='node_memory_MemAvailable_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "MemAvailable: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")

  local promql='node_memory_Cached_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "Cached: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")

  local promql='node_memory_SwapCached_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "SwapCached: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")
  local promql='node_memory_SwapTotal_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "SwapTotal: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")
  local promql='node_memory_SwapFree_bytes{hostname="'$PROMETHEUS_HOST'"} / 1024'
  printf "SwapFree: %.0f kB\n" $(get_prometheus_metric "${promql}" "${jquery}")

}

function check_prometheus_filesystem () {

  # size
  get_prometheus_ql 'node_filesystem_size_bytes{hostname="'$PROMETHEUS_HOST'"} / 1000' | \
    jq -r '.data.result[] | [.metric.device,.metric.fstype,.metric.mountpoint,.value[1]] | join(" ")' > /tmp/prometheus_fs_size_$$.data

  # available
  get_prometheus_ql 'node_filesystem_avail_bytes{hostname="'$PROMETHEUS_HOST'"} / 1000' | \
    jq -r '.data.result[] | [.metric.device, .metric.fstype, .metric.mountpoint, .value[1]] | join(" ")' > /tmp/prometheus_fs_avaliable_$$.data

  # used
  get_prometheus_ql '(node_filesystem_size_bytes{hostname="'$PROMETHEUS_HOST'"} - node_filesystem_free_bytes{hostname="'$PROMETHEUS_HOST'"}) / 1000' | \
    jq -r '.data.result[] | [.metric.device, .metric.fstype, .metric.mountpoint, .value[1]] | join(" ")' > /tmp/prometheus_fs_used_$$.data


  echo '<<<df>>>'
  # device fstype size used available percentage% mountpoint
  grep '/dev' /tmp/prometheus_fs_size_$$.data | while read fs_device fs_type fs_mount size; do
    available=$(printf "%.0f" $(grep "$fs_device $fs_type $fs_mount" /tmp/prometheus_fs_avaliable_$$.data | awk '{print $4}'))
    used=$(printf "%.0f" $(grep "$fs_device $fs_type $fs_mount" /tmp/prometheus_fs_used_$$.data | awk '{print $4}'))
    size=$(printf "%.0f" $size)
    percentage=$(( $used / $size ))
    printf "%s %s %s %.0f %.0f %.0f%% %s\n" $fs_device $fs_type $size $used $available $percentage $fs_mount 
  done

  # clean files
  rm -f /tmp/prometheus_fs_*_$$.data

}

##############################################################################

# prometheus status check
#curl -skG -u $PROMETHEUS_USER:$PROMETHEUS_PASSWORD ${PROMETHEUS_SERVER}/api/v1/query?query=cafebabe | jq -r

export PROMETHEUS_HOST=$(curl -skG -u $PROMETHEUS_USER:$PROMETHEUS_PASSWORD ${PROMETHEUS_SERVER}/api/v1/targets | \
  jq -r '.data.activeTargets[] | select(.labels.job == "ssh") |  [.labels.hostname, .labels.instance] | join(" ")' | \
  sort | uniq | grep $CMK_HOST_IP | awk -F'[ :]' '{print $1}')

if [[ "$PROMETHEUS_HOST" -eq "" ]]; then
  echo 'Host not monitored in Prometheus' >&2
  exit 2
fi


# Check_mk agent header 
echo "<<<check_mk>>>
Version: 1.1
AgentOS: Prometheus via PromQL and JQuery
PrometheusServer: ${PROMETHEUS_SERVER}"

check_prometheus_uptime
check_prometheus_memory
check_prometheus_cpu
check_prometheus_filesystem
