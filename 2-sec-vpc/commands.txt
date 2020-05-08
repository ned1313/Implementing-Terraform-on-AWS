# Rename the terraform.tfvars.example file to terraform.tfvars and change the region
# to your desired region

# Initialize the terraform configuration
terraform init

# Plan the terraform deployment
terraform plan -out vpc.tfplan

# Apply the deployment
terraform apply "vpc.tfplan"

# Make note of the VPC ID output