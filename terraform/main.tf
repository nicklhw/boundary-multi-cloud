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
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.33.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.89.0"
    }
  }
}

provider "boundary" {
  addr                   = var.boundary_cluster_url
  scope_id               = "global"
  auth_method_id         = var.boundary_password_auth_method_id
  auth_method_login_name = var.global_admin_username
  auth_method_password   = var.global_admin_password
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_admin_namespace
  auth_login_userpass {
    namespace = var.vault_admin_namespace
    username  = var.vault_admin_username
    password  = var.vault_admin_password
  }
}