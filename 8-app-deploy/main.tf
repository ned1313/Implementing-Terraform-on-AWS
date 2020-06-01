##################################################################################
# VARIABLES
##################################################################################

variable "region" {
  type    = string
  default = "us-east-1"
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}


##################################################################################
# RESOURCES
##################################################################################

resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

#####################
# RDS Security group
#####################

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_security_group_rule" "allow_asg" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.asg_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}

resource "aws_security_group_rule" "egress_rds" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.15.0"

  identifier = "globo-dev-db"

  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t2.large"
  allocated_storage = 5

  name                   = "globoappdb"
  username               = "globoadmin"
  password               = "YourPwdShouldBeLongAndSecure!"
  port                   = "3306"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  iam_database_authentication_enabled = true

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  tags = {
    Owner       = "App"
    Environment = "dev"
  }

  # DB subnet group
  db_subnet_group_name = data.terraform_remote_state.network.outputs.db_subnet_group

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "globo-app-db"

  # Database Deletion Protection
  deletion_protection = false

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8"
    },
    {
      name  = "character_set_server"
      value = "utf8"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}

###########################################
# Launch configuration and Auto scale group
###########################################

resource "aws_security_group" "asg_sg" {
  name        = "asg-security-group"
  description = "Security group for ASG"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg_sg.id
}

resource "aws_security_group_rule" "egress_lc" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg_sg.id
}

resource "aws_launch_configuration" "web_servers" {
  name            = "web-servers"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.asg_sg.id]
  user_data       = file("${path.module}/user_data.txt")
}

resource "aws_lb_target_group" "web_servers" {
  name     = "web-servers-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_autoscaling_group" "web_servers" {
  name = "web-servers-asg"

  max_size         = 4
  min_size         = 0
  desired_capacity = 2

  health_check_grace_period = 300
  health_check_type         = "EC2"

  launch_configuration = aws_launch_configuration.web_servers.name

  vpc_zone_identifier = data.terraform_remote_state.network.outputs.public_subnets

  target_group_arns = [aws_lb_target_group.web_servers.arn]

}


###############################################
# Applicaiton load balancer
###############################################

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_security_group_rule" "allow_http_alb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "egress_alb" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_lb" "web_server" {
  name               = "web-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.terraform_remote_state.network.outputs.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "development"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_server.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_servers.arn
  }
}
