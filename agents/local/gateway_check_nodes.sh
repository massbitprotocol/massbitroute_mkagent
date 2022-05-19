#!/bin/bash
_nodes=/massbit/massbitroute/app/src/sites/services/gateway/http.d/gw-dot-mainnet-nodes.conf
check_http="/usr/lib/nagios/plugins/check_http"
_http() {
	_hostname=$1
	_id=$(echo $_hostname | cut -d'.' -f1)
	_ip=$2
	_port=$3
	_path=$4
	_token=$5
	_checkname="mbr-node-$_id"
	$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t 3 --ssl -p $_port | tail -1 |
		awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
}
if [ -f "$_nodes" ]; then
	awk -f /massbit/massbitroute/app/src/sites/services/mkagent/agents/extract_nodes.awk /massbit/massbitroute/app/src/sites/services/gateway/http.d/gw-dot-mainnet-nodes.conf | while read _token _domain _url; do
		_path="/"
		_ip=$(echo $_url | cut -d'/' -f3)
		_port=443
		_http $_domain $_ip $_port $_path $_token

	done
fi
