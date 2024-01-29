/*
If your claim response contained http://my-domain, you might create
the above filter like this: \"auth0\" in
\"/userinfo/http:~1~1my-domain/sub\".

Setting up managed group filters
https://developer.hashicorp.com/boundary/tutorials/identity-management/oidc-idp-groups#managed-groups-filters
*/
resource "boundary_managed_group" "oidc_managed_group" {
  name           = "Multi Cloud Demo Admins"
  description    = "Multi Cloud Demo Admins - Auth0 Managed Group"
  auth_method_id = boundary_auth_method_oidc.provider.id
  filter         = "\"multi-cloud-demo-admin\" in \"/userinfo/boundary~1roles\""
}

resource "boundary_role" "oidc_admin_role" {
  name          = "Multi Cloud Demo Admin"
  description   = "Multi Cloud Demo Admin role"
  principal_ids = [boundary_managed_group.oidc_managed_group.id]
  grant_strings = ["id=*;type=*;actions=*"]
  scope_id      = boundary_scope.proj.id
}

resource "boundary_managed_group" "dba" {
  name           = "Multi Cloud Demo DBA"
  description    = "Multi Cloud Demo DBA - Auth0 Managed Group"
  auth_method_id = boundary_auth_method_oidc.provider.id
  filter         = "\"dba\" in \"/userinfo/boundary~1roles\""
}

# Grant strings: https://developer.hashicorp.com/boundary/docs/concepts/security/permissions/resource-table
resource "boundary_role" "dba_role" {
  name          = "Multi Cloud Demo DBA"
  description   = "Multi Cloud Demo DBA role"
  principal_ids = [boundary_managed_group.dba.id]
  grant_strings = [
    "id=${boundary_target.dba.id};type=target;actions=list,read,authorize-session",
  ]
  scope_id      = boundary_scope.proj.id
}

#resource "boundary_role" "oidc_user_role" {
#  name          = "User Role"
#  description   = "user role"
#  principal_ids = [boundary_managed_group.oidc_managed_group.id]
#  grant_strings = ["id=*;type=*;actions=*"]
#  scope_id      = "global"
#}
