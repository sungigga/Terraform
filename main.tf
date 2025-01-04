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

# Create Launch Template
 resource "aws_launch_template" "prod"{
   image_id = "ami-05c172c7f0d3aed00"
   instance_type = "t2.micro"

   network_interfaces {
      security_groups = [ aws_security_group.instance.id ]
   }
   
   user_data = base64encode(<<-EOF
      #!bin/bash
      echo "Hello, world" > index.html
      nohup busybox httpd -f -p ${var.server_port} &
      EOF
   )

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
     name = "vpc-id"
     values = [ data.aws_vpc.default.id ]
   } 
}
# Create Auto scaling Group 
resource "aws_autoscaling_group" "prod" {
   launch_template {
     id = aws_launch_template.prod.id
   } 
   vpc_zone_identifier = data.aws_subnets.default.ids # Dynamically fetched subnets
   
   target_group_arns = [ aws_lb_target_group.asg.arn ]
   health_check_type = "ELB"
   
   min_size = 2
   max_size = 6

   tag {
     key = "Name"
     value = "ASGInstance"
     propagate_at_launch = true
   }
}
# Load Balancer Deployment
resource "aws_lb" "prod" {    # Create Application load balancer
   name = "prod-ag-example"
   load_balancer_type = "application"
   subnets = data.aws_subnets.default.ids
   security_groups = [ aws_security_group.alb.id ]
}
resource "aws_lb_listener" "http" {
   load_balancer_arn = aws_lb.prod.arn
   port = 80
   protocol = "HTTP"
   
   # return a 404 page by default
   default_action {
     type = "fixed-response"
     fixed_response {
       content_type = "text/plain"
       message_body = "404: page not found"
       status_code = 404
     }
   }
}

resource "aws_security_group" "alb" {
   name = "prod-alb"

# Allow inbound HTTP requests
ingress  {
   from_port = 80
   to_port = 80
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }  

# Allow all outbound request
egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
}
}
# Create target group
resource "aws_lb_target_group" "asg" {
   port = var.server_port
   protocol = "HTTP"
   vpc_id = data.aws_vpc.default.id
  
  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}
 
 # Create listener rule
 resource "aws_lb_listener_rule" "asg" {
   listener_arn = aws_lb_listener.http.arn
   priority = 100

   condition {
     path_pattern {
       values = ["*"]
     }
   }
   action {
     type = "forward"
     target_group_arn = aws_lb_target_group.asg.arn
   }
   
 }

 output "alb_dns_name" {
   value = aws_lb.prod.dns_name
   description = "The load balancer domain"
   
 }