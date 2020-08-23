# Terraform script for AWS EC2 Windows 2019 Server and Centos 7 instances

Website: https://www.terraform.io

## Getting Started

Here I will describe how to build terraform script, wich not just make two instances, but also install on them web server (on Centos- it's nginx, on Windows 2019 Server it's IIS, of course)

## Authors

* **Andrew Savelyev**- _linkedin_ - [Linkedin](https://www.linkedin.com/in/andrew-savelyev-791526127/)

## Prerequisites

* [Terraform](https://www.terraform.io/downloads.html) 0.10.x

## Set up your environment

Firstival you need to set the two variables var.aws_access and var.aws_secret. Whith their help terraform will get access to your AWS environment. I did that in terraform.tfvars file, where i described all variables. So, also you could make terraform.tfvars file and describe vars in there, how i did.

terraform.tfvars
``` bash
aws_access="A...5"
aws_secret="Bw...ae"
```

Now lets describe terraform file.
In the top of the .tf file i declared two variables- var.aws_access and var.aws_secret to access AWS environment:
``` bash
variable "aws_access" {}
variable "aws_secret" {}
```

I declared that i will use AWS provider in the ca-central-1 region:

``` bash
provider "aws" {
  access_key = var.aws_access
  secret_key = var.aws_secret
  region     = "ca-central-1"
}
```

Then to use ssh key in my terraform environment, i should create corresponding resourse aws_key_pair, where i described the path to my .pub key:

```bash
resource "aws_key_pair" "ssh_key" {
  key_name   = "aws_ssh_key"
  public_key = file("~/.ssh/aws.pub")
}
```

Also, to set static public ip for all my two instances, which i will create little later, i created resource "aws_eip", which uses in AWS to set Elastic IP (static public IP):

```bash
resource "aws_eip" "win_ip" {
  instance = aws_instance.win_2019.id
  vpc      = true
}
resource "aws_eip" "centos_ip" {
  instance = aws_instance.centos.id
  vpc      = true
}
```

Next i already creates my windows 2019 server instance. I describe image, which i used- "ami-0f38562b9d4de0dfe". You should check image name which you use, because in dependence on region, name can change. 

Also check type of instance. For example in TIER free package (which i use) i could use only t2.micro and t3.micro instance type. 

And i describe security group, which i will create in this .tf file later. 
I describe ssh key, which i will use to connect to this instance. 

And then i describe parametr "ebs_block_device" for a few reasons. The first indicates that i need to delete this block device (which will show up in AWS console as Volume) in stage of deleting this instance- "delete_on_termination = true". And the second- i describe size, name and type of this volume.

And of course, i use parametr "üser data" to describe which actions i need to do after instance will be created- installation of IIS Web Server:

```bash
resource "aws_instance" "win_2019" {
  ami           = "ami-0f38562b9d4de0dfe"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_web.id]
  key_name               = aws_key_pair.ssh_key.id
  ebs_block_device {
    device_name           = "/dev/sdc"
    volume_size           = 30
    volume_type           = "standard"
    delete_on_termination = true
  }
  get_password_data     =   "true"
  user_data = <<EOF
    <powershell>
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    </powershell>
  EOF
  tags = {
    Name = "Win 2019 Server"
  }
}
```
Here i describe that i creates one more instance- Centos. Also, like in previous instance creation, i describe wich AWS image i will use- "ami-0affd4508a5d2481b". Thats defines CentOS 7 (x86_64) edition.
And now, in "user_data" section i describe that after installation of image will run script file nginx.sh, which will install nginx web server:

```bash
resource "aws_instance" "centos" {
  ami           = "ami-0affd4508a5d2481b"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_web.id]
  key_name               = aws_key_pair.ssh_key.id

  ebs_block_device {
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = "standard"
    delete_on_termination = true
  }
  user_data = file("nginx.sh")

  tags = {
    Name = "Centos"
  }
}
```

By the way, in this script, nginx.sh i am not just install nginx. Also i get server's local ipv4 address by running "curl http://169.254.169.254/latest/meta-data/local-ipv4". After that i assign this value to variable $myip and then- redirect text with this variable to nginx's index.html file:

```bash
#!/bin/bash
yum -y update
yum install -y epel-release
yum install -y nginx
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h2>WebServer with IP: $myip</h2><br>Built by Terraform!" > /usr/share/nginx/html/index.html
echo "<br><font color="green">Hello world ))!" >> /usr/share/nginx/html/index.html
sudo systemctl start nginx
chkconfig nginx on
```

Then we creates the security group "my_web", which describe incoming (ingres) and outgoing (egress) rules:

```bash
resource "aws_security_group" "my_web" {
  name        = "web_security"
  description = "for_web_servers"
  ingress {
    description = "https_to_web"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http_to_web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "icmp"
    from_port   = 8
    to_port     = 0
  }
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
```

To know, which exactly passwort was generated, i used function output "win2019_password", which decrypt this one key pair:

```bash
output "win2019_password" {
  value = "${rsadecrypt(aws_instance.win_2019.password_data, file("/home/andrey/.ssh/aws"))}"
}
```

So, to enter via RDP to this Win 2019 server i can use username Administrator and password, which terraform output will show me. And i even should't enter the AWS console and look for it.

```bash
output "centos_ip" {
  value = aws_eip.centos_ip.public_ip
}
output "win_ip" {
  value = aws_eip.win_ip.public_ip
}
```
Thats it.
