# The following variable is used to configure the provider's authentication
# token. You don't need to provide a token on the command line to apply changes,
# though: using the remote backend, Terraform will execute remotely in Terraform
# Cloud where your token is already securely stored in your workspace!
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.50.0"
      configuration_aliases = [ aws.main, aws.cloudfront ]
    }
  }
}
