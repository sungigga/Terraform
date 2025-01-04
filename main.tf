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

# Create Launch Config
 resource "aws_launch_configuration" "prod"{
   image_id = "ami-05c172c7f0d3aed00"
   instance_type = "t2.micro"
   security_groups = [ aws_security_group.instance.id ]
   user_data = <<-EOF
               #!bin/bash
               echo "Hello, world" > index.html
               nohup busybox httpd -f -p ${var.server_port} &
               EOF

# Required when using a launch configuration with an auto scaling group.
   lifecycle {
     create_before_destroy = true
   }
 }

# Use a Data Source to fetch the default VPC
data "aws_vpc" "default" {
   default = true 
}

# Usa a Data Source to lookup subnets with the vpc
data "aws_subnets" "default"{
   filter {
     name = "vcp-id"
     values = [ data.aws_vpc.default.id ]
   } 
}
# Create Auto scaling Group 
resource "aws_autoscaling_group" "prod" {
   launch_configuration = aws_launch_configuration.prod
   vpc_zone_identifier = data.aws_subnets.default.ids # Dynamically fetched subnets
   min_size = 2
   max_size = 6

   tag {
     key = "Name"
     value = "ASGInstance"
     propagate_at_launch = true
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