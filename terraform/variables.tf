variable "boundary_cluster_url" {
  type    = string
  default = ""
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