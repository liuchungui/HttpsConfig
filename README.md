# 使用说明
使用`create.sh`可以生成多个由Let's Encrypt签发的证书，有效期为三个月。可以参考`renew.sh`脚本配置一个重新签名的脚本，然后放到服务器定时运行。想法主要参考文章：[Let's Encrypt文章](http://deadlion.cn/2016/09/28/Let's-Encrypt.html)而来。

使用create.sh脚本来生成证书，它使用的参数：

```
	必填参数：
	-n NAME     域名，如果是多个域名，用空格分开，例如www.baidu.com pan.baidu.com
可选参数：
	-p PATH		证书存储的目录，不传，默认存储在当前目录下
```