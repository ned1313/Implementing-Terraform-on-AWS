terraform {
    backend "s3" {
        key = "lambda/terraform.tfstate"
    }
}