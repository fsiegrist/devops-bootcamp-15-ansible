provider "aws" {
  region = "eu-central-1"
}

variable vpc_cidr_block {}
variable private_subnet_cidr_blocks {}
variable public_subnet_cidr_blocks {}

data "aws_availability_zones" "available" {}  # queries the azs in the region of the provider

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "myapp-vpc"
  cidr = var.vpc_cidr_block
  # Best practice for configuring subnets for an EKS cluster: configure one private and one public subnet in each availability zone of the current region.
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets = var.public_subnet_cidr_blocks
  azs = data.aws_availability_zones.available.names 
  
  enable_nat_gateway = true
  single_nat_gateway = true  # all private subnets will route their internet traffic through this single NAT gateway
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"  # for AWS Cloud Control Manager (it needs to know which VPC it should connect to)
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"  # for AWS Cloud Control Manager (it needs to know which subnet it should connect to)
    "kubernetes.io/role/elb" = 1  # for AWS Load Balancer Controller (it needs to know in which subnet to create the load balancer accessible from the internet)
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = 1 
  }
}