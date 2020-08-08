#!/bin/bash
yum -y update
yum install -y epel-release
yum install -y nginx
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h2>WebServer with IP: $myip</h2><br>Built by Terraform!" > /usr/share/nginx/html/index.html
echo "<br><font color="green">Hello world ))!" >> /usr/share/nginx/html/index.html
sudo systemctl start nginx
chkconfig nginx on