#!/bin/bash
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{sub(/^mbr_/,"",$1);print $1}')
if [ "$type" != "gateway" ]; then
	exit 0
fi
SITE_ROOT=/massbit/massbitroute/app/src/sites/services/$type
if [ -f "$SITE_ROOT/.env_raw" ]; then
	source $SITE_ROOT/.env_raw >/dev/null
fi

check_dns="/massbit/massbitroute/app/src/sites/services/mkagent/plugins/check_dns"
check_http="/massbit/massbitroute/app/src/sites/services/mkagent/plugins/check_http"
# if [ ! -f "$check_http" ]; then
# 	apt install -y monitoring-plugins
# fi
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
	if [ "$_ip" == "null" ]; then
		_ip=$(nslookup -type=A $_hostname 8.8.8.8 | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)

		# _ip=$(nslookup -type=A $_hostname | awk '/Address:/{print $2}' | tail -2 | head -1)
	fi

	# if [ "$_ip" == "443" ]; then return; fi

	_port=$3
	_path=$4
	_rtt=0

	_token=$5
	_blockchain=$6
	_checkname=$7
	_method=$8
	_info="$9"
	_msg="$_info ip=$_ip"
	if [ \( "$_path" != "/ping" \) -a \( "$_path" != "/_ping" \) ]; then
		_rtt="$(timeout 3 curl -sk https://$_ip/_rtt)"
		_rtt_w=$(echo $_rtt | wc -w)
		if [ $_rtt_w -ne 1 ]; then _rtt=0; fi
		_msg="$_msg rtt=$_rtt"
	fi

	if [ -z "$_method" ]; then _method=POST; fi
	if [ -z "$_checkname" ]; then
		_checkname="mbr-node-$_idd"
	fi
	if [ "$_method" == "POST" ]; then
		if [ "$_blockchain" == "dot" ]; then
			$check_http -I $_ip -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v rtt=$_rtt -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="size=0|time=0";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};rtt_msg="";if(rtt>0){rtt_msg="|rtt="rtt};print st,checkname,perf""rtt_msg,$1,msg}'
		else
			$check_http -I $_ip -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=POST --post='{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' -t $_timeout --ssl -p $_port | tail -1 |
				awk -F'|' -v rtt=$_rtt -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="size=0|time=0";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};rtt_msg="";if(rtt>0){rtt_msg="|rtt="rtt};print st,checkname,perf""rtt_msg,$1,msg}'
		fi
	elif [ "$_method" == "GET" ]; then
		$check_http -I $_ip -H $_hostname -k "x-api-key: $_token" -u $_path -T application/json --method=GET -t $_timeout --ssl -p $_port | tail -1 |
			awk -F'|' -v rtt=$_rtt -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="size=0|time=0";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};rtt_msg="";if(rtt>0){rtt_msg="|rtt="rtt};print st,checkname,perf""rtt_msg,$1,msg}'
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
			__info="group=${_type} geo=${_continent}-${_country} domain=$_domain id=$_id"
			_http $_domain $_ip $_port $_path $_token $_blockchain mbr-api-$_ip POST "$__info"
			_http $_domain $_ip $_port $_path_ping $_token $_blockchain mbr-api-${_ip}-ping GET "$__info"
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
	# _type=""
	# _http_api_check_geo $_dm $_pt $_api_check_dir $_type
	rm -rf $_api_check_dir
}
_http_api() {
	_f=$(ls /massbit/massbitroute/app/src/sites/services/gateway/http.d/dapi-*.conf | head -1)
	_suff=${_blockchain}"-"${_network}
	_domain=$(awk -v suff=$_suff '/server_name/{sub(/*;$/,suff,$2);print $2}' $_f | head -1)"."$DOMAIN
	_path=$(awk '/location \/[^ ]/{print $2}' $_f | head -1)
	_port=443
	# _ip_google=$(nslookup -type=A $_domain 8.8.8.8 | awk '/Address:/{print $2}' | tail -1)

	_ip_google=$(nslookup -type=A $_domain 8.8.8.8 | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)

	# _ip=$(host $_domain | awk '{print $4}' | head -1)
	#	_ip="127.0.0.1"
	_token="empty"
	if [ -n "$_domain" ]; then

		#_http_api_check $_domain $_pat
		_http $_domain $_ip_google $_port $_path $_token $_blockchain mbr-api-google POST "domain=$_domain id=$_id $__info ip=$_ip_google"
		_domain1=$(echo $_domain | sed "s/$_suff/${_suff}-${_continent}/g")
		_http $_domain1 "null" $_port $_path $_token $_blockchain mbr-api-${_continent} POST "domain=$_domain1 id=$_id geo=${_continent} $__info "
		_domain2=$(echo $_domain | sed "s/$_suff/${_suff}-${_continent}-${_country}/g")
		_http $_domain2 "null" $_port $_path $_token $_blockchain mbr-api-${_continent}-${_country} POST "domain=$_domain2 id=$_id geo=${_continent}-${_country} $__info"

		# check dns
		# _h=$(awk '/nameserver/{print $2}' /etc/resolv.conf | head -1)
		# _checkname="dns_$_h"
		# _msg=""
		# $check_dns -H $_domain | awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'

		# for _h in 185.228.168.9 1.1.1.1 8.8.8.8 9.9.9.9 208.67.222.222; do
		# 	_checkname="dns_$_h"

		# 	$check_dns -H $_domain -s $_h | awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'
		# done

		# _checkname="dns_ns1"

		# $check_dns -H $_domain -s ns1.$DOMAIN | awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'
		# _checkname="dns_ns2"

		# $check_dns -H $_domain -s ns2.$DOMAIN | awk -F'|' -v checkname=$_checkname -v msg="$_msg" '{st=0;perf="-";if(index($1,"CRITICAL") != 0){st=2} else if(index($1,"WARNING") != 0){st=1} else {gsub(/ /,"|",$2);perf=$2;};print st,checkname,perf,$1,msg}'

		# end check dns
	fi
}
_test_speed() {

	_ip=$1
	_id=$2
	_info=$3
	_ff=/tmp/test_speed_$_ip

	if [ -f "$_ff" ]; then
		_cont=$(cat $_ff)
		if [ -z "$_cont" ]; then
			rm $_ff
		else
			cat $_ff
			return
		fi

	fi
	tmp=$(mktemp)
	_tm=5
	_tm1=4
	_speed=0
	timeout $_tm wget -O $tmp --no-check-certificate https://$_ip/__log/128M
	# if [ $? -eq 0 ]; then
	_size=$(stat --printf="%s" $tmp)
	if [ $_size -gt 0 ]; then
		_speed=$(expr $_size / $_tm1 / 1024)
		echo "0 mbr-node-speed-${_id} speed=$_speed speed is $_speed KB/s ip=$_ip $_info" >$_ff
	fi
	# fi
	rm $tmp
	if [ -f "$_ff" ]; then
		cat $_ff
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
			# _path_rtt="/_rtt"
			_port=443
			_domain="${_id}.node.mbr.$DOMAIN"
			_info="geo=${_continent}-${_country}"
			_http $_domain $_ip $_port $_path $_token $_blockchain mbr-node-$_id POST $_info
			_http $_ip $_ip $_port $_path_ping $_token $_blockchain mbr-node-${_id}-ping GET $_info
			# _http $_ip $_ip $_port $_path_rtt $_token $_blockchain mbr-node-${_id}-rtt GET $_info

			# _test_speed $_ip $_id $_info
		done
	done
}
_node_check() {
	_node_check_dir=$(mktemp -d)
	_type="-${_continent}-${_country}"
	_node_check_geo $_node_check_dir $_type
	_type="-${_continent}"
	_node_check_geo $_node_check_dir $_type
	# _type=""
	# _node_check_geo $_node_check_dir $_type
	rm -rf $_node_check_dir
}

if [ $# -gt 0 ]; then
	$@
	exit 0
fi

mbr=$SITE_ROOT/mbr
if [ -f "$mbr" ]; then $mbr node nodeinfo; fi

tmp=$(mktemp)
echo "0 node_info - hostname=$(hostname) status=${_status} operateStatus=${_opstatus} type=$type ip=$_myip id=$_node_id blockchain=$_blockchain network=$_network continent=$_continent country=$_country" >>$tmp
_node_check >>$tmp
_http_api >>$tmp

mv $tmp $_cache_f
cat $_cache_f
