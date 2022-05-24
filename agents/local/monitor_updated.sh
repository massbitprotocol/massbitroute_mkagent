#!/bin/sh
_f=/tmp/mbr_monitor_updated
if [ -f "$_f" ]; then
	_t=$(cat $_f)
	_now=$(date +%s)
	_delay=$(expr $_now - $_t)
	if [ $_delay -gt 120 ]; then
		echo 2 "job_monitor_delay t=$_delay Delay in $_delay second"
	else
		echo 0 "job_monitor_delay t=$_delay Delay in $_delay second"
	fi
fi
