#!/bin/bash

cd /root/acme-tiny
python acme_tiny.py --account-key bangying.org/account.key --csr bangying.org/domain.csr --acme-dir /alidata/www/challenges/ > signed.crt
if [ $? != 0 ];then
	echo "签名失败";
	exit;
fi
wget -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > intermediate.pem
cat signed.crt intermediate.pem > chained.pem
mv signed.crt intermediate.pem chained.pem bangying.org/
