# Use account_claims_maps and claims_scopes to request claims from
# IDP and map them Boundary account attributes
# https://dev-p6g32x14ae33zvpy.us.auth0.com/.well-known/openid-configuration
# OIDC support claims: https://auth0.com/docs/get-started/apis/scopes/openid-connect-scopes
resource "boundary_auth_method_oidc" "provider" {
  name                 = "Auth0"
  description          = "OIDC auth method for Auth0"
  scope_id             = "global"
  issuer               = var.auth0_domain
  client_id            = var.auth0_client_id
  client_secret        = var.auth0_client_secret
  signing_algorithms   = ["RS256"]
  api_url_prefix       = var.boundary_cluster_url
  is_primary_for_scope = true
  state                = "active-public"
  max_age              = 0
  account_claim_maps   = ["email=email", "name=name", "sub=sub"]
  claims_scopes        = ["email", "profile"]
}

#resource "boundary_account_oidc" "oidc_user" {
#  name           = "nick-hashicorp"
#  description    = "OIDC account for Nick-HashiCorp"
#  auth_method_id = boundary_auth_method_oidc.provider.id
#  issuer         = var.auth0_domain
#  subject        = var.auth0_subject
#}