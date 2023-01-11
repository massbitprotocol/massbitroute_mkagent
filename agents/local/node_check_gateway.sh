#!/bin/bash
exit 0
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{sub(/^mbr_/,"",$1);print $1}')
if [ "$type" != "node" ]; then
	exit 0
fi
SITE_ROOT=/massbit/massbitroute/app/src/sites/services/$type

_cache_f=/tmp/node_check_gateway
_node_id_f="$SITE_ROOT/vars/ID"
_blockchain_f="$SITE_ROOT/vars/BLOCKCHAIN"
_ip_f="$SITE_ROOT/vars/IP"
_network_f="$SITE_ROOT/vars/NETWORK"
_raw_f="$SITE_ROOT/vars/RAW"
_env="$SITE_ROOT/.env_raw"
if [ -f "$_env" ]; then source $_env; fi
_blockchain="eth"
_network="mainnet"
_timeout=3
if [ -f "$_ip_f" ]; then
	_myip=$(cat $_ip_f)
fi

if [ -f "$_blockchain_f" ]; then
	_blockchain=$(cat $_blockchain_f)
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

if [ \( -z "$_continent" \) -o \( "$_continent" == "null" \) -o \( -z "$_country" \) -o \( "$_country" == "null" \) ]; then exit 0; fi

check_http="/usr/lib/nagios/plugins/check_http"
_http() {
	_hostname=$1
	_id=$(echo $_hostname | cut -d'.' -f1)
	_ip=$2
	if [ "$_ip" == "443" ]; then return; fi
	_port=$3
	_path=$4
	_token=$5
	_blockchain=$6
	_checkname=$7
	_method=$8
	_info="$9"
	_rtt=0

	_msg="$_info ip=$_ip"
	if [ \( "$_path" != "/ping" \) -a \( "$_path" != "/_ping" \) ]; then
		_rtt="$(timeout 3 curl -sk https://$_ip/_rtt)"
		_rtt_w=$(echo $_rtt | wc -w)
		if [ $_rtt_w -ne 1 ]; then _rtt=0; fi
		_msg="$_msg rtt=$_rtt"
	fi

	if [ -z "$_method" ]; then _method=POST; fi
	if [ -z "$_checkname" ]; then
		_checkname="mbr-node-$_id"
	fi
	if [ "$_method" == "POST" ]; then
		if [ "$_blockchain" == "dot" ]; then
			$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' rtt=$_rtt -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="size=0|time=0";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};rtt_msg="";if(rtt>0){rtt_msg="|rtt="rtt};print st,checkname,perf""rtt_msg,$1,msg}'
		else
			$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v rtt=$_rtt -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="size=0|time=0";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};rtt_msg="";if(rtt>0){rtt_msg="|rtt="rtt};print st,checkname,perf""rtt_msg,$1, msg}'
		fi
	elif [ "$_method" == "GET" ]; then
		$check_http -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=GET -t $_timeout --ssl -p $_port | tail -1 |
			awk -F'|' -v rtt=$_rtt -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="size=0|time=0";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};rtt_msg="";if(rtt>0){rtt_msg="|rtt="rtt};print st,checkname,perf""rtt_msg,$1, msg}'
	fi

}
_node_check_geo() {
	_tmpd=$1
	_type=$2

	_status=0

	# for _ss in 0-1 1-1; do
	for _ss in 1-1; do
		_listid=listid-${_blockchain}-${_network}${_type}-$_ss
		timeout 3 curl -skL https://portal.$DOMAIN/deploy/info/gateway/$_listid >/tmp/$_listid
		if [ $? -ne 0 ]; then continue; fi
		echo >>/tmp/$_listid
		_n=$(awk 'NF > 0' /tmp/$_listid | wc -l)
		if [ $_n -gt 0 ]; then _status=1; fi

		cat /tmp/$_listid | while read _id _user _block _net _ip _continent _country _token _status _approve _remain; do
			if [ -z "$_id" ]; then continue; fi
			if [ -f "$_tmpd/$_id" ]; then continue; fi
			touch $_tmpd/$_id
			_path="/_node/$_node_id/"
			_path_ping="/_nodeip/$_myip/_ping"
			_port=443
			_domain="$_id.gw.mbr.$DOMAIN"
			_info="geo=${_continent}-${_country}"
			_http $_domain $_ip $_port $_path $_token $_blockchain mbr-gateway-$_id POST $_info
			# _http $_ip $_ip $_port $_path_ping $_token $_blockchain mbr-gateway-${_id}-ping GET $_info
		done
	done

	return $_status
}
_node_check() {
	_st=0
	_node_check_dir=$(mktemp -d)
	_type="-${_continent}-${_country}"
	_node_check_geo $_node_check_dir $_type
	_st=$?
	if [ $_st -eq 0 ]; then
		_type="-${_continent}"
		_node_check_geo $_node_check_dir $_type
		_st=$?
	fi
	if [ $_st -eq 0 ]; then
		_type=""
		_node_check_geo $_node_check_dir $_type
	fi
	rm -rf $_node_check_dir
}
cache=$1
if [ -z "$cache" ]; then cache=0; fi
if [ $cache -ne 1 ]; then
	if [ -f "$_cache_f" ]; then
		cat $_cache_f
	fi

	exit 0
fi
# rm $SITE_ROOT/.env_raw $SITE_ROOT/.env
# git -C $SITE_ROOT reset --hard

mbr=$SITE_ROOT/mbr
if [ -f "$mbr" ]; then $mbr node nodeinfo; fi

tmp=$(mktemp)
echo "0 node_info - $(TZ=":Asia/Ho_Chi_Minh" date) hostname=$(hostname) status=${_status} operateStatus=${_opstatus} type=$type ip=$_myip id=$_node_id blockchain=$_blockchain network=$_network continent=$_continent country=$_country" >>$tmp
_node_check >>$tmp
mv $tmp $_cache_f

cat $_cache_f
