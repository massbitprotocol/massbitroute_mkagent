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
#ip=$($curl https://internal.monitor.mbr.massbitroute.net/__my/ip)

cache_ip_file=/tmp/ip
if [ -f "$cache_ip_file" ]; then
	ip=$(cat $cache_ip_file)
	if [ -z "$ip" ]; then
		ip=$($curl http://ipv4.icanhazip.com)
		echo $ip >$cache_ip_file
	fi

fi
if [ ! -f "/usr/bin/nc" ]; then apt install -y netcat; fi
/usr/bin/nc -vz $ip 443
is_open=$?
# is_open=$($curl https://internal.monitor.mbr.massbitroute.net/__check/port/$ip/tcp/443)
if [ $is_open -eq 0 ]; then
	echo $is_open mbr-firewall-443 - "Port 443 is open" >$cache_file
else
	echo 2 mbr-firewall-443 - "Port 443 is closed" >$cache_file
fi
