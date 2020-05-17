#############################################################################
# VARIABLES
#############################################################################

variable "aws_bucket_prefix" {
  type    = string
  default = "globo"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  type = string
  description = "Name of bucket for remote state"
}

variable "dynamodb_table_name" {
  type = string
  description = "Name of dynamodb table for remote state locking"
}

locals {
  bucket_name = "${var.aws_bucket_prefix}-build-logs-${random_integer.rand.result}"
}

#############################################################################
# PROVIDERS
#############################################################################

provider "aws" {
  version = "~> 2.0"
  region  = var.region
}

#############################################################################
# DATA SOURCES
#############################################################################

data "aws_s3_bucket" "state_bucket" {
  bucket = var.state_bucket
}

data "aws_dynamodb_table" "state_table" {
  name = var.dynamodb_table_name
}

#############################################################################
# RESOURCES
#############################################################################  

resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

resource "aws_codecommit_repository" "vpc_code" {
  repository_name = "vpc-deploy"
  description     = "Code for deploying VPCs"
}

resource "aws_s3_bucket" "vpc_deploy_logs" {
  bucket = local.bucket_name
  acl    = "private"
}

resource "aws_iam_role" "code_build_assume_role" {
  name = "code-build-assume-role-${random_integer.rand.result}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloud_build_policy" {
  role = aws_iam_role.code_build_assume_role.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
            "Effect": "Allow",
            "Action": ["dynamodb:*"],
            "Resource": [
                "${data.aws_dynamodb_table.state_table.arn}"
            ]
        },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${data.aws_s3_bucket.state_bucket.arn}",
        "${data.aws_s3_bucket.state_bucket.arn}/*",
        "${aws_s3_bucket.vpc_deploy_logs.arn}",
        "${aws_s3_bucket.vpc_deploy_logs.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "build_project" {
  name          = "vpc-deploy-project"
  description   = "Project to deploy VPCs"
  build_timeout = "5"
  service_role  = aws_iam_role.code_build_assume_role.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.vpc_deploy_logs.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_ACTION"
      value = "PLAN"
    }

    environment_variable {
      name  = "TF_VERSION_INSTALL"
      value = "0.12.24"
    }

    environment_variable {
      name  = "TF_BUCKET"
      value = var.state_bucket
    }

    environment_variable {
      name  = "TF_REGION"
      value = var.region
    }

    environment_variable {
      name  = "WORKSPACE_NAME"
      value = "Default"
    }

  }

  logs_config {

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.vpc_deploy_logs.id}/build-log"
    }
  }

  source {
    type     = "CODECOMMIT"
    location = aws_codecommit_repository.vpc_code.clone_url_http
  }

  source_version = "master"

}

resource "aws_iam_role" "codepipeline_role" {
  name = "vpc-codepipeline-role-${random_integer.rand.result}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "vpc-codepipeline_policy-${random_integer.rand.result}"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.vpc_deploy_logs.arn}",
        "${aws_s3_bucket.vpc_deploy_logs.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codepipeline" "codepipeline" {
  name     = "vpc-deploy-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.vpc_deploy_logs.bucket
    type     = "S3"

  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.vpc_code.repository_name
        BranchName     = "master"
      }
    }
  }

  stage {
    name = "Development"

    action {
      name             = "Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["plan_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
        EnvironmentVariables = jsonencode(
          [
            {
              name  = "TF_ACTION"
              value = "PLAN"
              type  = "PLAINTEXT"
            },
            {
              name  = "WORKSPACE_NAME"
              value = "Development"
              type  = "PLAINTEXT"
            }
          ]
        )
      }
    }

    action {
      name             = "Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["apply_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
        EnvironmentVariables = jsonencode(
          [
            {
              name  = "TF_ACTION"
              value = "APPLY"
              type  = "PLAINTEXT"
            },
            {
              name  = "WORKSPACE_NAME"
              value = "Development"
              type  = "PLAINTEXT"
            }
          ]
        )
      }
    }
  }
}