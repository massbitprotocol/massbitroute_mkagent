#!/bin/bash
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{sub(/^mbr_/,"",$1);print $1}')
if [ "$type" != "node" ]; then
	exit 0
fi
SITE_ROOT=/massbit/massbitroute/app/src/sites/services/$type
if [ -f "$SITE_ROOT/.env_raw" ]; then
	source $SITE_ROOT/.env_raw >/dev/null
fi
check_http="/usr/lib/nagios/plugins/check_http"

if [ ! -f "$check_http" ]; then
	apt install -y monitoring-plugins
fi
_cache_f=/tmp/${type}_check_datasource
cache=$1

if [ -z "$cache" ]; then cache=0; fi
if [ $cache -ne 1 ]; then
	if [ -f "$_cache_f" ]; then
		cat $_cache_f
	fi

	exit 0
fi
shift

_blockchain_f="$SITE_ROOT/vars/BLOCKCHAIN"
_network_f="$SITE_ROOT/vars/NETWORK"
_blockchain="eth"
_network="mainnet"

_timeout=3
if [ -f "$_blockchain_f" ]; then
	_blockchain=$(cat $_blockchain_f)
fi

if [ -f "$_network_f" ]; then
	_network=$(cat $_network_f)
fi

_raw_f="$SITE_ROOT/vars/RAW"
if [ -f "$_raw_f" ]; then
	_country=$(cat $_raw_f | jq .geo.countryCode | sed 's/\"//g')
	_continent=$(cat $_raw_f | jq .geo.continentCode | sed 's/\"//g')
	_status=$(cat $_raw_f | jq .status | sed 's/\"//g')
	_data_uri=$(cat $_raw_f | jq .dataSource | sed 's/\"//g')
fi

# _data_uri_f="/massbit/massbitroute/app/src/sites/services/node/vars/DATA_URI"

#_data_uri=$(grep proxy_pass $SITE_ROOT/http.d/*.conf | tail -1 | awk '/proxy_pass/{sub(/;$/,"",$2);print $2}')

if [ -n "$_data_uri" ]; then

	# _blockchain=$(cat /massbit/massbitroute/app/src/sites/services/node/vars/BLOCKCHAIN)
	# _network=$(cat /massbit/massbitroute/app/src/sites/services/node/vars/NETWORK)

	# _raw=/massbit/massbitroute/app/src/sites/services/node/vars/RAW
	# if [ -f "$_raw" ]; then
	# 	_country=$(cat $_raw | jq .geo.countryCode | sed 's/\"//g')
	# 	_continent=$(cat $_raw | jq .geo.continentCode | sed 's/\"//g')
	# fi

	# _data_uri=$(cat $_data_uri_f | sed 's/ //g')
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

	_tmp=$(mktemp)
	if [ "$_blockchain" == "dot" ]; then
		$check_http -H $_hostname -u $_path -T application/json --method=POST --post='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' -t $_timeout $_ssl_opt $_port_opt | tail -1 |
			awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}' >>$_tmp
		_n1=$(timeout 10 curl -sk https://portal.$DOMAIN/deploy/info/block.dot.latest)

		_n22=$(timeout 10 curl -sk --location --request POST $_data_uri \
			--header 'Content-Type: application/json' \
			--data-raw '{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' | jq .result.block.header.number | sed 's/\"//g' | sed 's/^0x//g')
		if [ \( "$_n1" != "null" \) -a \( "$_n22" != "null" \) ]; then
			#_n1=$((16#$_n11))
			_n2=$((16#$_n22))
			_n=$(expr $_n1 - $_n2)
			_st=0
			if [ $_n -gt 1000 ]; then _st=2; fi
			if [ $_n -gt 100 ]; then _st=1; fi
			echo "$_st mbr-datasource-sync delay=$_n base=$_n1 source=$_n2 delay=$_n" >>$_tmp
		else
			echo "2 mbr-datasource-sync - base=$_n1 source=null" >>$_tmp
		fi

	else
		$check_http -H $_hostname -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t $_timeout $_ssl_opt $_port_opt | tail -1 |
			awk -F'|' -v checkname=$_checkname '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1}' >>$_tmp
		_n1=$(timeout 10 curl -sk https://portal.$DOMAIN/deploy/info/block.eth.latest)

		_n22=$(timeout 10 curl -sk --location --request POST $_data_uri \
			--header 'Content-Type: application/json' \
			--data-raw '{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' | jq .result.number | sed 's/\"//g' | sed 's/^0x//g')
		if [ \( "$_n1" != "null" \) -a \( "$_n22" != "null" \) ]; then
			#	_n1=$((16#$_n11))
			_n2=$((16#$_n22))
			_n=$(expr $_n1 - $_n2)
			_st=0
			if [ $_n -gt 1000 ]; then _st=2; fi
			if [ $_n -gt 100 ]; then _st=1; fi
			echo "$_st mbr-datasource-sync delay=$_n base=$_n1 source=$_n2 delay=$_n" >>$_tmp
		else
			echo "2 mbr-datasource-sync - base=$_n1 source=null" >>$_tmp
		fi

	fi
	mv $_tmp $_cache_f

	cat $_cache_f
fi
