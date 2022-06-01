#!/bin/bash
ip=$(cat /massbit/massbitroute/app/src/sites/services/*/vars/IP | head -1)
if [ -z "$ip" ]; then exit 0; fi
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

if [ ! -f "/usr/bin/nc" ]; then apt install -y netcat; fi
/usr/bin/nc -vz $ip 443
is_open=$?
if [ $is_open -eq 0 ]; then
	echo $is_open mbr-firewall-443 - "Port 443 is open" >$cache_file
else
	echo 2 mbr-firewall-443 - "Port 443 is closed" >$cache_file
fi
cat $cache_file
