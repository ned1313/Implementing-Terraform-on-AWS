##################################################################################
# VARIABLES
##################################################################################

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_bucket_prefix" {
  type    = string
  default = "globo"
}

variable "network_state_bucket" {
  type        = string
  description = "name of bucket used for network state"
}

variable "network_state_key" {
  type        = string
  description = "name of key used for network state"
  default     = "networking/dev-vpc/terraform.tfstate"
}

variable "network_state_region" {
  type        = string
  description = "region used for network state"
  default     = "us-east-1"
}

locals {
  bucket_name = "${var.aws_bucket_prefix}-lambda-${random_integer.rand.result}"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  version = "~>2.0"
  region  = var.region
  profile = "app"
}

##################################################################################
# Data sources
##################################################################################

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.network_state_region
  }
}

##################################################################################
# RESOURCES
##################################################################################

resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

# Deploy the S3 bucket

resource "aws_s3_bucket" "lambda_functions" {
  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = true
}

# Put the Lambda function in the S3 bucket

resource "aws_s3_bucket_object" "lambda_function" {
  key        = "publishOrders.zip"
  bucket     = aws_s3_bucket.lambda_functions.id
  source     = "publishOrders.zip"
}

# Create a Security Group for Lambda

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Security group for Lambda"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

# Deploy the template

resource "aws_cloudformation_stack" "orders_stack" { 
  name = "orders-stack"
  capabilities = ["CAPABILITY_IAM"]

  parameters = {
      FunctionBucket = local.bucket_name
      FunctionKey = "publishOrders.zip"
      LambdaSecurityGroup = aws_security_group.lambda_sg.id
      SubnetIds = join(",",data.terraform_remote_state.network.outputs.public_subnets)
  }

  template_body = file("${path.module}/lambda.template")
}

##################################################################################
# OUTPUT
##################################################################################

output "template_output" {
  value = aws_cloudformation_stack.orders_stack.outputs
}