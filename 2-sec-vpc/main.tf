#############################################################################
# VARIABLES
#############################################################################

variable "region" {
  type    = string
  default = "us-east-1"
}


variable "vpc_cidr_range" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnets" {
  type = list(string)
  default = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "infra_subnets" {
  type = list(string)
  default = ["10.0.200.0/24", "10.0.201.0/24"]
}

#############################################################################
# PROVIDERS
#############################################################################

provider "aws" {
  version = "~> 2.0"
  region = var.region
}

#############################################################################
# DATA SOURCES
#############################################################################

data "aws_availability_zones" "azs" {}

#############################################################################
# RESOURCES
#############################################################################  

# Create security VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.33.0"

  name = "sec-vpc"
  cidr = var.vpc_cidr_range

  azs = slice(data.aws_availability_zones.available.names, 0, 1)
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  infra_subnets = var.infra_subnets

  tags = {
      Environment = "all"
      Team = "security"
  }

}





#############################################################################
# OUTPUTS
#############################################################################

output "vpc_id" {
  value = module.vpc.vpc_id
}
