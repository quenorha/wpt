#!/bin/sh

wget https://curl.se/ca/cacert.pem -o /root/cacert.pem
wget https://raw.githubusercontent.com/quenorha/wpt/main/curlrc -o /root/.curlrc
curl https://raw.githubusercontent.com/quenorha/wpt/main/install.sh -o $PWD/install.sh -s && chmod +x $PWD/install.sh && $PWD/install.sh


