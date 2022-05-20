#!/bin/bash
cache=$1
cache_file=/tmp/check_firewall
if [ -z "$cache" ]; then cache=0; fi
if [ $cache -ne 1 ]; then
	if [ -f "$cache_file" ]; then
		cat $cache_file
	fi
	exit 0
fi

curl="/usr/bin/curl -sk"
ip=$($curl https://internal.monitor.mbr.massbitroute.net/__my/ip)
is_open=$($curl https://internal.monitor.mbr.massbitroute.net/__check/port/$ip/tcp/443)
if [ $is_open -eq 0 ]; then
	echo $is_open mbr-firewall-443 - "Port 443 is open" >$cache_file
else
	echo 2 mbr-firewall-443 - "Port 443 is closed" >$cache_file
fi
