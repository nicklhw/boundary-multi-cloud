variable "boundary_cluster_url" {
  type    = string
  default = ""
}

variable "boundary_password_auth_method_id" {
}

variable "global_admin_username" {
  type    = string
  default = ""
}

variable "global_admin_password" {
  type    = string
  default = ""
}

variable "boundary_proj_name" {
  type    = string
  default = "Multi Cloud Demo"
}

variable "prefix" {
  type    = string
  default = "boundary-multi-cloud"
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aws_public_subnet_cidr" {
  type    = string
  default = "10.0.10.0/24"
}

variable "aws_private_subnet_cidr" {
  type    = string
  default = "10.0.20.0/24"
}

variable "aws_tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Project = "Multi Cloud Demo"
  }
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_rsa_public_key" {
  type = string
}

variable "vault_address" {
  type    = string
  default = ""
}

variable "vault_admin_username" {
  type    = string
  default = ""
}

variable "vault_admin_password" {
  type    = string
  default = ""
}

variable "vault_admin_namespace" {
  type    = string
  default = "admin"
}

variable "ssh_username" {
  type    = string
  default = ""
}

variable "s3_bucket_name" {
  type    = string
  default = "boundary-s3-bucket"
}

variable "auth0_domain" {
}

variable "auth0_client_id" {
}

variable "auth0_client_secret" {
}

variable "auth0_subject" {
}

variable "postgres_password" {
}

variable "vault_hvn_id" {}

variable "windows_instance_name" {
  type        = string
  description = "EC2 instance name for Windows Server"
  default     = "tfwinsrv01"
}

variable "windows_admin_password" {}

variable "azure_location" {
  type    = string
  default = "East US 2"
}

variable "azure_vnet_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azure_public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "azure_private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}