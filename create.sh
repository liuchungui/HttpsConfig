#!/bin/bash

#ssl路径
SSL_PATH=""

function usage() {
	echo "
必填参数：
	-n NAME     域名，如果是多个域名，用空格分开，例如www.baidu.com pan.baidu.com
可选参数：
	-p PATH		证书存储的目录，不传，默认存储在当前目录下
"
}

#后面带冒号，说明需要带参数
param_pattern="n:p:s:"
OPTIND=1
param_check=0
subjContent="/"
while getopts $param_pattern optname
	do
		#保存临时变量
		tmp_optind=$OPTIND
		tmp_optname=$optname
		tmp_optarg=$OPTARG

		#对参数进行检查
		OPTIND=$OPTIND-1
		if getopts $param_pattern optname ;then
			echo $param_pattern
			echo  "Error: argument value for option $tmp_optname"
			usage
			exit 1
		fi

		#恢复变量
		OPTIND=$tmp_optind
		optname=$tmp_optname

		case "$optname" in
			"n")
				length=${#tmp_optarg[*]}
				if [ "$tmp_optarg" == "" ];then
					echo "Error: 这个值需要是一个域名字符串"
					usage
					exit 1
				fi
				domainName=$tmp_optarg
				param_check=1
		        ;;
			"p")
				SSL_PATH=$tmp_optarg
		        ;;
	   #      "s")
				# if [ $tmp_optarg == "" ];then
				# 	echo "Error: -s 参数的值不能为空"
				# 	usage
				# 	exit 1
				# fi
				# subjContent=$tmp_optarg
	   #      ;;
	        "?")
		        echo "Error: Unknown option $OPTARG"
		        usage
				exit 1
		        ;;
		    ":")
		        echo "Error: No argument value for option $OPTARG"
		        usage
				exit 1
		        ;;
		    *)
		      # Should not occur
		        echo "Error: Unknown error while processing options"
		        usage
				exit 1
		        ;;
		esac
	done

if [ $param_check == 0 ];then
	echo "-n 是必选参数"
	usage
	exit 1
fi

#首先查看当前目录是否存在acme_tiny.py, 不存在则查看当前是否存在acme_tiny目录，不存在则clone项目
if [ ! -f acme_tiny.py ];then
	if [ ! -d acme_tiny ];then
		git clone https://github.com/diafygi/acme-tiny.git
	fi
	cd acme_tiny
fi

#遍历域名参数，写入conf中
confContent="
	[req]\n
	default_bits = 4096\n
	default_md = sha256\n
	default_keyfile = domain.key\n
	distinguished_name = req_distinguished_name\n
	req_extensions = req_ext\n
	string_mask = utf8only\n\n

	[ req_distinguished_name ]\n\n

	[ req_ext ]\n
	subjectAltName          = @alt_names\n\n

	[alt_names]\n";

#将域名用空格分隔成数组
OLD_IFS="$IFS" 
IFS=" " 
array=($domainName)
IFS="$OLD_IFS"
length=${#array[*]}

#当前生成的文件目录
if [ length > 1 ];then
	domainDir=${array[0]}"_group"
else
	domainDir=${array[0]}
fi

for ((i=0; i<$length; i++)); do
	echo ${array[$i]}
	((index=$i+1))
	confContent=$confContent"	DNS.$index = "${array[$i]}"\n"
done

#-e 输出到https.cnf文件中
echo -e $confContent > https.cnf

#创建私钥
openssl genrsa 4096 > account.key

#通过配置文件创建多域名请求证书
openssl req -utf8 -new -nodes -out domain.csr -config https.cnf -batch -subj "$subjContent"

#签名验证
python acme_tiny.py --account-key ./account.key --csr ./domain.csr --acme-dir /alidata/www/challenges/ > ./signed.crt

#获取上个命令执行结果，判断是否签名成功
if [ $? != 0 ];then
	# 签名失败，尝试使用python2.7
	python2.7 acme_tiny.py --account-key ./account.key --csr ./domain.csr --acme-dir /alidata/www/challenges/ > ./signed.crt
	if [ $? != 0 ];then
		echo "签名失败"
		exit 1;
	fi
fi

#将Let's Encrypt中间证书追加到证书中
wget -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > intermediate.pem
cat signed.crt intermediate.pem > chained.pem

#将证书放到对应的文件夹下
if [ -d $domainDir ];then
	rm -R $domainDir
fi
mkdir $domainDir
mv account.key domain.key domain.csr signed.crt intermediate.pem chained.pem $domainDir

#SSL_APTH传递时，将对应的目录文件移动到SSL_PATH目录下
if [ $SSL_PATH != "" ];then
	if [ ! -d $SSL_PATH ];then
		mkdir -p $SSL_PATH
	fi
	cp -R $domainDir/* $SSL_PATH
	echo "证书生成成功，存储在：$SSL_PATH"
else
	echo "证书生成成功，存储在：$(pwd)/${domainDir}"
fi


