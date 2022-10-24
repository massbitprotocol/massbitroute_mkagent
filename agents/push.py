#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import time

import requests

if __name__ == "__main__":
    url = os.environ["URL"]
    token = os.environ["TOKEN"]
    agent = os.environ["CHECK_MK_AGENT"]
    push_url = os.environ["PUSH_URL"]
    # print(agent)
    # while True:
    #     try:
    agent_data = subprocess.check_output([agent])
    print(agent_data)
    url_post = "{}/{}/{}".format(url, push_url, token)
    print(url_post)
    resp = requests.post(url_post, data=agent_data)
    # if resp.status_code != 200:
    #     raise RuntimeError("Server responded with " + str(resp))
        # time.sleep(30)

        # except Exception as e:
        #     print(e)
        #     time.sleep(30)
        #     continue
