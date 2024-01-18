terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = ">=1.0.7"
    }
    http = {
      source  = "hashicorp/http"
      version = ">=3.2.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">=2.3.2"
    }
  }
}

provider "boundary" {
  addr                   = var.boundary_cluster_url
  scope_id               = "global"
  auth_method_login_name = var.global_admin_username
  auth_method_password   = var.global_admin_password
}

provider "aws" {
  region = var.aws_region
}

