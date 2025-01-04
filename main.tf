 provider "aws" {
    region = "eu-west-2"
 }
 resource "aws_instance" "prod" {
    ami = "ami-05c172c7f0d3aed00"
    instance_type = "t2.micro" 
    vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = <<-EOF
               #!bin/bash
               echo "Hello, world" > index.html
               nohup busybox httpd -f -p ${var.server_port} &
               EOF
      user_data_replace_on_change = true

    tags = {
      Name = "caly-prod"
    }
 }

 resource "aws_security_group" "instance"{
   name = "caly-prod-instance"

   ingress {
      from_port = var.server_port
      to_port = var.server_port
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
   }
   
 }