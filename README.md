# terraform-aws-https-domain-301-redirect

## Use case:

You want to perform a https redirect `https://domain1.ext` to `https://domain2.ext` without using computing resources.

The best solution we could find when creating this project was:

-> domain1 -> r53 -> cloudfront -> s3 -> domain2

**Please note**: this is all open source, feel free to submit improvements to the code, I would especially like to be able to process multiple requests at the same time. Moving 'variables' into a standalone file for each request could help wit this.

## Run

1. Create an account with [Terraform](https://www.terraform.io/)
2. Download and install the CLI
3. Update the backend remote `orginization name` in the `backend.ft` file to match your terraform account.
4. Add your AWS IAM details to `redirects.tf`, make sure the user has all the permisisons needed.
5. From command line run `sh run.sh`

Special thanks for https://github.com/riboseinc/terraform-aws-s3-cloudfront-redirect who did most of the heavy lifting.

## Reset

From time to time your redirect may fail, for example if you dont have a hostfile setup in route53. If the run script fails you can reset the file ready for another run by running the reset.

Note: This removes the last domain details and resets for the next, we can improve the performance of this by moving them into a 'variables' file with the domain name. This will also mean we can run multiple run files at the same time.
