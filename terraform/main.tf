provider "boundary" {
  addr                   = var.boundary_cluster_url
  scope_id               = "global"
  auth_method_login_name = var.global_admin_username
  auth_method_password   = var.global_admin_password
}

data "boundary_scope" "org" {
  name     = "SEA"
  scope_id = "global"
}

# Create org scope
resource "boundary_scope" "proj" {
  name                     = var.boundary_proj_name
  scope_id                 = data.boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}