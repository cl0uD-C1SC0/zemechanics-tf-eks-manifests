
#################
# VPC VARIABLES #  
#################

variable "vpc_name" {
  default = "ze-mechanics-vpc"
  type = string
  description = "Nome da VPC"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  type = string
  description = "CIDR da VPC"
}

#################
# EKS VARIABLES #
#################

variable "cluster_name" {
  default = "zemechanics-cluster"
  type = string
  description = "Nome do cluster EKS"
}

variable "nodegroup_name" {
  default = "zemechanics-ndg-01"
  type = string
  description = "Nome do NodeGroup"
}

variable "aws_iam_user_arn" {
  type = string
  description = "ARN do seu usuario AWS"
}

#########################
# API SECRET VARIABLES  #
#########################


# COLOCAR NO RDS INSTANCE O IMPORT DESSAS VARIAVEIS ABAIXO
# NA ENVIRONMENT VARIABLE DA FUNCAO LAMBDA TBM
variable "database_username" {
  type = string
  default = "admin"
}

variable "database_password" {
  type = string
  default = "rootroot"
}

variable "secret_key" {
  type = string
  default = "1234"
}

variable "secret_key_jwt" {
  default = "admin123"
}

variable "user_name" {
  default = "admin"
}

variable "user_password" {
  default = "admin1234"
}

variable "mail_server_address" {
  default = "maildev-svc"
}

# GITHUB
variable "github_username" {
  default = "cl0uD-C1SC0"
}

variable "github_repo" {
  type = string
  description = "Nome do repositorio do APP Zemechanics"
}