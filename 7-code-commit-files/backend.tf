terraform {
    backend "s3" {
        key = "networking/terraform.tfstate"
    }
}