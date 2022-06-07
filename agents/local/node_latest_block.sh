#!/bin/bash
cache=$1
if [ $cache -ne 1 ]; then exit 0; fi
_type_f=/massbit/massbitroute/app/src/sites/services/api/vars/TYPE
if [ -f "$_type_f" ]; then
	_type=$(cat $_type_f)
fi
if [ "$_type" == "mbr-api" ]; then
	_n11=$(timeout 10 curl -sk --location --request POST 'https://dot.getblock.io/mainnet/' --header 'x-api-key: 6c4ddad0-7646-403e-9c10-744f91d37ccf' --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0","method":"chain_getBlock","params": [],"id": 1}' | jq .result.block.header.number | sed 's/\"//g' | sed 's/^0x//g')
	if [ -n "$_n11" ]; then
		_n1=$((16#$_n11))
		if [ $_n1 -gt 0 ]; then
			echo $_n1 >/massbit/massbitroute/app/src/sites/services/api/public/deploy/info/block.dot.latest
		fi
	fi

	_n11=$(timeout 10 curl --location --request POST 'https://rpc.ankr.com/eth' \
		--header 'Content-Type: application/json' \
		--data-raw '{"id": "blockNumber", "jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["latest", false]}' | jq .result.number | sed 's/\"//g' | sed 's/^0x//g')
	if [ -n "$_n11" ]; then
		_n1=$((16#$_n11))
		if [ $_n1 -gt 0 ]; then
			echo $_n1 >/massbit/massbitroute/app/src/sites/services/api/public/deploy/info/block.eth.latest
		fi
	fi
fi
