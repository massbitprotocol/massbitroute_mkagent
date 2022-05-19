#!/bin/bash
check_http="/usr/lib/nagios/plugins/check_http"
if [ ! -f "$check_http" ]; then
	apt install -y monitoring-plugins
fi

_post_data='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}'
_data_uri_f="/massbit/massbitroute/app/src/sites/services/node/vars/DATA_URI"

if [ -f "$_data_uri_f" ]; then
	_blockchain="/massbit/massbitroute/app/src/sites/services/node/vars/BLOCKCHAIN"
	if [ "$_blockchain" == "dot" ]; then
		_post_data='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}'
	fi

	_data_uri=$(cat $_data_uri_f | sed 's/ //g')
	_scheme=$(echo $_data_uri | awk -F[/:] '{print $1}')
	_ssl_opt=""

	_port=80
	if [ "$_scheme" == "https" ]; then
		_ssl_opt="--ssl"
		_port=443
	fi

	_hostname1=$(echo $_data_uri | awk -F'/' '{print $3}')
	_hostname=$(echo $_hostname1 | awk -F':' '{print $1}')
	_port=$(echo $_hostname1 | awk -F':' '{print $2}')
	_port_opt=""
	_path=$(echo $_data_uri | cut -d'/' -f4-)
	if [ -z "$_path" ]; then
		_path="/"
	else
		_path="/$_path"
	fi

	if [ -n "$_port" ]; then
		_port_opt="-p $_port"
	fi

	_checkname="mbr-datasource-$_data_uri"
	$check_http -H $_hostname -u $_path -T application/json --method=POST --post=$_post_data -t 3 $_ssl_opt $_port_opt | tail -1 |
		awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
fi
