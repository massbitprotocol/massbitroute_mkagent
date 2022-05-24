#!/bin/sh
_check() {
	_f=$1
	_type=$2
	if [ -f "$_f" ]; then
		_t=$(cat $_f)
		_now=$(date +%s)
		_delay=$(expr $_now - $_t)
		if [ $_delay -gt 60 ]; then
			echo 2 "job_${_type}_delay t=$_delay Delay in $_delay second"
		else
			echo 0 "job_${_type}_delay t=$_delay Delay in $_delay second"
		fi
	fi
}
_f=/tmp/mbr_monitor_updated
_check $_f monitor
_f=/tmp/mbr_mkagent_updated
_check $_f mkagent
