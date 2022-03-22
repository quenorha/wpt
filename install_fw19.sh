#!/bin/sh

wget https://curl.se/ca/cacert.pem -O /root/cacert.pem
wget https://raw.githubusercontent.com/quenorha/wpt/main/curlrc -O /root/.curlrc
curl https://raw.githubusercontent.com/quenorha/wpt/main/install.sh -o $PWD/install.sh -s && chmod +x $PWD/install.sh && $PWD/install.sh


