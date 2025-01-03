 provider "aws" {
    region = "eu-west-2"
 }
 resource "aws_instance" "prod" {
    ami = "ami-019374baf467d6601"
    instance_type = "t2.micro" 

    tags = {
      Name = "caly-prod"
    }
 }