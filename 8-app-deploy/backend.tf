terraform {
    backend "s3" {
        key = "app/terraform.tfstate"
    }
}