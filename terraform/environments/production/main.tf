terraform {
  required_version = ">= 0.12"
  backend "s3" {
    bucket         = "<% .Name %>-production-terraform-state"
    key            = "infrastructure/terraform/environments/production/main"
    encrypt        = true
    region         = "<% index .Params `region` %>"
    dynamodb_table = "<% .Name %>-production-terraform-state-locks"
  }
}

# Instantiate the production environment
module "production" {
  source      = "../../modules/environment"
  environment = "production"

  # Project configuration
  project             = "<% .Name %>"
  region              = "<% index .Params `region` %>"
  allowed_account_ids = ["<% index .Params `accountId` %>"]
  # ECR configuration
  ecr_repositories = ["production"]

  # EKS configuration
  eks_worker_instance_type = "t2.small"
  eks_worker_asg_min_size  = 3
  eks_worker_asg_max_size  = 6

  # EKS-Optimized AMI for your region: https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html
  # https://us-east-1.console.aws.amazon.com/systems-manager/parameters/%252Faws%252Fservice%252Feks%252Foptimized-ami%252F1.14%252Famazon-linux-2%252Frecommended%252Fimage_id/description?region=us-east-1
  eks_worker_ami = "ami-07be7092831897fd6"

  # Hosting configuration
  s3_hosting_buckets = [
    "<% index .Params `productionHost` %>"
  ]
  s3_hosting_cert_domain = "<% index .Params `productionHost` %>"

  # DB configuration
  db_instance_class = "db.t3.small"
  db_storage_gb = 100

}
