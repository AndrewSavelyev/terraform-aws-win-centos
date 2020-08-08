variable "aws_access" {}
variable "aws_secret" {}

provider "aws" {
  access_key = var.aws_access
  secret_key = var.aws_secret
  #region     = "us-east-1"
  region  = "ca-central-1"
}
resource "aws_key_pair" "ssh_key" {
  key_name   = "aws_ssh_key"
  public_key = file("~/.ssh/aws.pub")
}
resource "aws_eip" "win_ip" {
  instance = aws_instance.win_2019.id
  vpc      = true
}
resource "aws_eip" "centos_ip" {
  instance = aws_instance.centos.id
  vpc      = true
}
resource "aws_instance" "win_2019" {
  ami           = "ami-0df364e027762ec43"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_web.id]
  key_name               = aws_key_pair.ssh_key.id
  ebs_block_device {
    device_name           = "/dev/sdc"
    volume_size           = 50
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
resource "aws_instance" "centos" {
  ami           = "ami-04a25c39dc7a8aebb"
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
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "allow_tls"
  }
}
output "win2019_password" {
  value = "${rsadecrypt(aws_instance.win_2019.password_data, file("/home/andrey/.ssh/aws"))}"
}
/*
output "instance_centos_ip" {
  value = aws_instance.centos.*.public_ip
}
output "instance_win2019_ip" {
  value = aws_instance.win_2019.*.public_ip
}
*/
output "centos_ip" {
  value = aws_eip.centos_ip.public_ip
}
output "win_ip" {
  value = aws_eip.win_ip.public_ip
}