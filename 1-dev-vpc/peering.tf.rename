#############################################################################
# VARIABLES
#############################################################################

variable "destination_vpc_id" {
  type = string
}

variable "peer_role_arn" {
  type = string
}


#############################################################################
# PROVIDER
############################################################################# 

provider "aws" {
  version = "~> 2.0"
  region  = var.region
  alias   = "peer"
  profile = "infra"
  assume_role {
      role_arn = var.peer_role_arn
  }

}

#############################################################################
# DATA SOURCES
#############################################################################

data "aws_caller_identity" "peer" {
  provider = aws.peer
}

#############################################################################
# RESOURCES
############################################################################# 

# Create the peering connection

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = var.destination_vpc_id
  peer_owner_id = data.aws_caller_identity.peer.account_id
  peer_region   = var.region
  auto_accept   = false

}

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true

}
