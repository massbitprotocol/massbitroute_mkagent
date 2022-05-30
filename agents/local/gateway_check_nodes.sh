#!/bin/bash
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{sub(/^mbr_/,"",$1);print $1}')
if [ "$type" != "gateway" ]; then
	exit 0
fi
if [ ! -f "/usr/bin/wget" ]; then apt install -y wget; fi
_cache_f=/tmp/gateway_check_nodes
_node_id_f="/massbit/massbitroute/app/src/sites/services/$type/vars/ID"
_ip_f="/massbit/massbitroute/app/src/sites/services/$type/vars/IP"
_blockchain_f="/massbit/massbitroute/app/src/sites/services/$type/vars/BLOCKCHAIN"
_network_f="/massbit/massbitroute/app/src/sites/services/$type/vars/NETWORK"
_raw_f="/massbit/massbitroute/app/src/sites/services/$type/vars/RAW"
_env="/massbit/massbitroute/app/src/sites/services/$type/.env_raw"
if [ -f "$_env" ]; then source $_env; fi
_blockchain="eth"
_network="mainnet"
_timeout=3
if [ -f "$_blockchain_f" ]; then
	_blockchain=$(cat $_blockchain_f)
fi

if [ -f "$_ip_f" ]; then
	_myip=$(cat $_ip_f)
fi

if [ -f "$_node_id_f" ]; then
	_node_id=$(cat $_node_id_f)
fi

if [ -f "$_network_f" ]; then
	_network=$(cat $_network_f)
fi

if [ -f "$_raw_f" ]; then
	_country=$(cat $_raw_f | jq .geo.countryCode | sed 's/\"//g')
	_continent=$(cat $_raw_f | jq .geo.continentCode | sed 's/\"//g')
fi
echo "0 node_info - type=$type ip=$_myip id=$_node_id blockchain=$_blockchain network=$_network continent=$_continent country=$_country"

check_http="/usr/lib/nagios/plugins/check_http"
_http() {
	_hostname=$1
	_id=$(echo $_hostname | cut -d'.' -f1)
	_ip=$2
	_port=$3
	_path=$4
	_token=$5
	_blockchain=$6
	_checkname=$7
	_method=$8
	if [ -z "$_method" ]; then _method=POST; fi
	if [ -z "$_checkname" ]; then
		_checkname="mbr-node-$_id"
	fi
	if [ "$_method" == "POST" ]; then
		if [ "$_blockchain" == "dot" ]; then
			$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
		else
			$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
		fi
	elif [ "$_method" == "GET" ]; then
		$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=GET -t $_timeout --ssl -p $_port | tail -1 |
			awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}'
	fi

}
_test_speed() {
	_ip=$1
	_id=$2
	wget --output-document=/dev/null --no-check-certificate https://$_ip/__log/128M 2>&1 | tail -2 | head -1 | awk -v id=$_id '{sub(/\(/,"",$3);sub(/\)/,"",$4);print "0 mbr_node_speed_"id,"speed="$3,"speed is",$3,$4}'
}
cache=$1
if [ -z "$cache" ]; then cache=0; fi
if [ $cache -ne 1 ]; then
	if [ -f "$_cache_f" ]; then
		cat $_cache_f
	fi

	exit 0
fi

tmp=$(mktemp)
for _ss in 0-1 1-1; do
	_listid=listid-${_blockchain}-${_network}-$_ss
	curl -skL https://portal.$DOMAIN/deploy/info/node/$_listid >/tmp/$_listid
	echo >>/tmp/$_listid
	cat /tmp/$_listid | while read _id _user _block _net _ip _continent _country _token _status _approve _remain; do
		_path="/"
		_path_ping="/_ping"
		_port=443
		_domain="$_id.node.mbr.$DOMAIN"
		_http $_domain $_ip $_port $_path $_token $_blockchain mbr-node-${_continent}-${_country}-$_id >>$tmp
		_http $_ip $_ip $_port $_path_ping $_token $_blockchain mbr-node-${_continent}-${_country}-${_id}-ping GET >>$tmp
		_test_speed $_ip $_id

	done

done

mv $tmp $_cache_f
