#!/bin/bash
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{print $1}')
if [ "$type" != "mbr_gateway" ]; then
	exit 0
fi
_blockchain_f="/massbit/massbitroute/app/src/sites/services/gateway/vars/BLOCKCHAIN"
_network_f="/massbit/massbitroute/app/src/sites/services/gateway/vars/NETWORK"
_blockchain="eth"
_network="mainnet"
_timeout=3
if [ -f "$_blockchain_f" ]; then
	_blockchain=$(cat $_blockchain_f)
fi
if [ -f "$_network_f" ]; then
	_network=$(cat $_network_f)
fi

_nodes=/massbit/massbitroute/app/src/sites/services/gateway/http.d/gw-${_blockchain}-${_network}-nodes.conf
check_http="/usr/lib/nagios/plugins/check_http"
_http() {
	_hostname=$1
	_id=$(echo $_hostname | cut -d'.' -f1)
	_ip=$2
	_port=$3
	_path=$4
	_token=$5
	_blockchain=$6

	_checkname="mbr-node-$_id"
	if [ "$_blockchain" == "dot" ]; then
		$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' -t $_timeout --ssl -p $_port | tail -1 |
			awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
	else
		$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t $_timeout --ssl -p $_port | tail -1 |
			awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
	fi

}
if [ -f "$_nodes" ]; then
	cache=$1
	if [ -z "$cache" ]; then cache=0; fi
	if [ $cache -ne 1 ]; then
		if [ -f "/tmp/gateway_check_nodes" ]; then
			cat /tmp/gateway_check_nodes
		fi

		exit 0
	fi

	tmp=$(mktemp)
	awk -f /massbit/massbitroute/app/src/sites/services/mkagent/agents/extract_nodes.awk $_nodes | while read _token _domain _url; do
		_path="/"
		_ip=$(echo $_url | cut -d'/' -f3)
		_port=443
		_http $_domain $_ip $_port $_path $_token $_blockchain >>$tmp

	done
	mv $tmp /tmp/gateway_check_nodes
fi
