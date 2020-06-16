# Implementing-Terraform-on-AWS

Welcome to Implementing Terraform on AWS. These exercise files are meant to accompany my course on [Pluralsight](https://app.pluralsight.com/library/courses/implementing-terraform-aws/).  The course was developed using version 0.12.24 of Terraform.  As far as I know there are no coming changes that will significantly impact the validity of these exercise files.  But I also don't control all the plug-ins, providers, and modules used by the configurations.

## Using the files

Each folder follows in succession as the course progresses. All of the folders include a `commands.txt` file that has example commands for that portion of the exercise. All folders also include an example `terraform.tfvars` file creatively named `terraform.tfvars.example`. Simply update the values in the file and rename it to `terraform.tfvars`.

Many of the modules in the course build on the infrastructure created by previous modules. Bearing that in mind, jumping around in the course will be difficult. When you complete a module, you might be tempted to run `terraform destroy` to delete the resources. You can do that, but remember that you will need to deploy the resources again a future module.

## Course Prerequisites

There are a few prerequisites for working with the course files.

### Visual Studio Code

You are going to want to use Visual Studio Code or a similar code editor. Personally I like VS Code because it's free and cross-platform, and it has source control built-in. But hey, that's just me. You do you.

### AWS Accounts

This is a course all about using Terraform on AWS. It is safe to assume you'll need at least one AWS account and the **root** or **Full Administrator** role on that account. The exercises use two accounts - one for networking and another for security - to demonstrate multiple instances of the AWS provider.

There are also three Users created for the exercises. Two in the networking account and one in the security account. You should create those users and assign them the level of access documented in the course.

## MONEY!!!

A gentle reminder about cost. The course will have you creating resources in AWS.  Some of the resources are not going to be 100% free. I have tried to use free resources when possible, but EC2 instance, S3 Storage, and RDS all cost money. We're probably talking a couple dollars for the duration of the exercises, but it won't be zero.

Each module builds on the previous one to create a complete deployment for the Globomantics scenario. As I mentioned before, destroying the resources after each module will make things more difficult. For that reason, I waited until the last module to deploy any actual EC2 or RDS instances. Those are the things that will actually cost you money. Once you complete the course, I highly recommend tearing everything down with `terraform destroy` or by deleting the resources in AWS.

## Conclusion

I hope you enjoy taking this course as much as I did creating it.  I'd love to hear feedback and suggestions for revisions. Log an issue on this repo or hit me up on Twitter.

Thanks and happy automating!

Ned
