#!/bin/bash
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{sub(/^mbr_/,"",$1);print $1}')
if [ "$type" != "gateway" ]; then
	exit 0
fi
SITE_ROOT=/massbit/massbitroute/app/src/sites/services/$type
if [ -f "$SITE_ROOT/.env_raw" ];then
    source $SITE_ROOT/.env_raw >/dev/null
fi

check_http="/usr/lib/nagios/plugins/check_http"
if [ ! -f "$check_http" ]; then
	apt install -y monitoring-plugins
fi
if [ ! -f "/usr/bin/wget" ]; then apt install -y wget; fi
_cache_f=/tmp/${type}_check_nodes
cache=$1
if [ -z "$cache" ]; then cache=0; fi
if [ $cache -ne 1 ]; then
	if [ -f "$_cache_f" ]; then
		cat $_cache_f
	fi

	exit 0
fi
shift

_node_id_f="$SITE_ROOT/vars/ID"
_ip_f="$SITE_ROOT/vars/IP"
_blockchain_f="$SITE_ROOT/vars/BLOCKCHAIN"
_network_f="$SITE_ROOT/vars/NETWORK"
_raw_f="$SITE_ROOT/vars/RAW"

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
	_status=$(cat $_raw_f | jq .status | sed 's/\"//g')
	_opstatus=$(cat $_raw_f | jq .operateStatus | sed 's/\"//g')
fi


_http() {
	_hostname=$1

	_idd=$(echo $_hostname | cut -d'.' -f1)
	_ip=$2
	if [ "$_ip" == "443"]; then return; fi
	_port=$3
	_path=$4
	_token=$5
	_blockchain=$6
	_checkname=$7
	_method=$8
	_info=$9
	_msg="$_info ip=$_ip"
	if [ -z "$_method" ]; then _method=POST; fi
	if [ -z "$_checkname" ]; then
		_checkname="mbr-node-$_idd"
	fi
	if [ "$_method" == "POST" ]; then
		if [ "$_blockchain" == "dot" ]; then
			$check_http -I $_ip -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'
		else
			$check_http -I $_ip -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'
		fi
	elif [ "$_method" == "GET" ]; then
		$check_http -I $_ip -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=GET -t $_timeout --ssl -p $_port | tail -1 |
			awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'
	fi

}

_http_api_check_geo() {
	_dm=$1
	_pt=$2
	_tmpd=$3
	_type=$4

	# _tmp=$(mktemp)
	for _ss in 0-1 1-1; do
		_listid=listid-${_blockchain}-${_network}${_type}-$_ss
		timeout 3 curl -skL https://portal.$DOMAIN/deploy/info/gateway/$_listid >/tmp/$_listid
		if [ $? -ne 0 ]; then
			# rm $_tmp
			continue
			#return
		fi
		echo >>/tmp/$_listid
		cat /tmp/$_listid | while read _id _user _block _net _ip _continent _country _token _status _approve _remain; do
			if [ -z "$_id" ]; then continue; fi
			if [ -f "$_tmpd/$_id" ]; then continue; fi
			touch $_tmpd/$_id
			_path="$_pt"
			_path_ping="/ping"
			_port=443
			_domain="$_dm"
			_token="empty"
			_http $_domain $_ip $_port $_path $_token $_blockchain mbr-api${_type}-$_ip POST "domain=$_domain id=$_id"
			_http $_domain $_ip $_port $_path_ping $_token $_blockchain mbr-api${_type}-${_ip}-ping GET "domain=$_domain id=$_id"
		done
	done
	# cat $_tmp
	# rm $_tmp

}
_http_api_check() {
	_dm=$1
	_pt=$2
	_api_check_dir=$(mktemp -d)
	_type="-${_continent}-${_country}"
	_http_api_check_geo $_dm $_pt $_api_check_dir $_type
	_type="-${_continent}"
	_http_api_check_geo $_dm $_pt $_api_check_dir $_type
	_type=""
	_http_api_check_geo $_dm $_pt $_api_check_dir $_type
	rm -rf $_api_check_dir
}
_http_api() {
	_f=$(ls /massbit/massbitroute/app/src/sites/services/gateway/http.d/dapi-*.conf | head -1)
	_domain=$(awk '/server_name/{sub(/;$/,"",$2);print $2}' $_f | head -1)
	_path=$(awk '/location \/[^ ]/{print $2}' $_f | head -1)
	# _port=443
	# _ip=$(nslookup -type=A $_domain | awk '/Address:/{print $2}' | tail -2 | head -1)
	# _ip=$(host $_domain | awk '{print $4}' | head -1)
	#	_ip="127.0.0.1"
	# _token="empty"
	if [ -n "$_domain" ]; then
		_http_api_check $_domain $_path
		# _http $_domain $_ip $_port $_path $_token $_blockchain mbr-api POST "domain=$_domain"
	fi
}
_node_check_geo() {
	_tmpd=$1
	_type=$2

	for _ss in 0-1 1-1; do
		_listid=listid-${_blockchain}-${_network}${_type}-$_ss
		timeout 3 curl -skL https://portal.$DOMAIN/deploy/info/node/$_listid >/tmp/$_listid
		if [ $? -ne 0 ]; then continue; fi
		echo >>/tmp/$_listid
		cat /tmp/$_listid | while read _id _user _block _net _ip _continent _country _token _status _approve _remain; do
			if [ -z "$_id" ]; then continue; fi
			if [ -f "$_tmpd/$_id" ]; then continue; fi
			touch $_tmpd/$_id
			_path="/"
			_path_ping="/_ping"
			_port=443
			_domain="${_id}.node.mbr.$DOMAIN"
			_http $_domain $_ip $_port $_path $_token $_blockchain mbr-node${_type}-$_id
			_http $_ip $_ip $_port $_path_ping $_token $_blockchain mbr-node${_type}-${_id}-ping GET
			#		_test_speed $_ip ${_continent}-${_country}-${_id} >>$tmp
		done
	done
}
_node_check() {
	_node_check_dir=$(mktemp -d)
	_type="-${_continent}-${_country}"
	_node_check_geo $_node_check_dir $_type
	_type="-${_continent}"
	_node_check_geo $_node_check_dir $_type
	_type=""
	_node_check_geo $_node_check_dir $_type
	rm -rf $_node_check_dir
}
_test_speed() {

	_ip=$1
	_id=$2
	_ff=/tmp/test_speed_$_id

	if [ -f "$_ff" ]; then
		_cont=$(cat $_ff)
		if [ -z "$_cont" ]; then
			rm $_ff
		else
			cat $_ff
		fi

		return
	fi
	tmp=$(mktemp)
	timeout 5 wget -O $tmp --no-check-certificate https://$_ip/__log/128M
	if [ $? -ne 0 ]; then
		rm $tmp
		return
	fi
	_size=$(stat --printf="%s" $tmp)
	if [ $_size -gt 0 ]; then
		_speed=$(expr $_size / 4 / 1024)
		echo "0 mbr-node-speed-${_id} speed=$_speed speed is $_speed KB/s ip=$_ip" >$_ff
		cat $_ff
	fi

	rm $tmp
}

if [ $# -gt 0 ]; then
	$@
	exit 0
fi

mbr=$SITE_ROOT/mbr
if [ -f "$mbr" ];then $mbr node nodeinfo;fi

tmp=$(mktemp)
echo "0 node_info - hostname=$(hostname) status=${_status} operateStatus=${_opstatus} type=$type ip=$_myip id=$_node_id blockchain=$_blockchain network=$_network continent=$_continent country=$_country" >>$tmp
_node_check >>$tmp
_http_api >>$tmp

mv $tmp $_cache_f
cat $_cache_f
