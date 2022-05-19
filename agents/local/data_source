#!/bin/bash
check_http="/usr/lib/nagios/plugins/check_http"
if [ ! -f "$check_http" ]; then
	apt install -y monitoring-plugins
fi

_data_uri_f="/massbit/massbitroute/app/src/sites/services/node/vars/DATA_URI"
if [ -f "$_data_uri_f" ]; then
	_data_uri=$(cat $_data_uri_f | sed 's/ //g')
	_scheme=$(echo $_data_uri | awk -F[/:] '{print $1}')
	_ssl_opt=""
	if [ "$_scheme" == "https" ]; then
		_ssl_opt="--ssl"
	fi
	_hostname=$(echo $_data_uri | awk -F[/:] '{print $4}')
	_checkname="mbr-datasource-$_hostname"
	$check_http -H $_hostname -u $_data_uri -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t 3 $_ssl_opt | tail -1 |
		awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
fi
