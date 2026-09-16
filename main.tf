module "zemechanics" {
  source = "./modules/manifests"
 
  vpc_name         = "ze-mechanics-vpc"
  vpc_cidr         = "10.0.0.0/16"
  cluster_name     = "zemechanics-cluster"
  nodegroup_name   = "zemechanics-ndg-01"
  github_username  = "cl0uD-C1SC0"
  github_repo      = "zemechanics-app"
  aws_iam_user_arn = "arn:aws:iam::<ACCOUNT_ID>:user/cloud_user" 
}