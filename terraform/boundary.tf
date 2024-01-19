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

### BEGIN: SSH Certification Injection Configuration ###

# Create a Vault credential store
resource "boundary_credential_store_vault" "vault_ssh_cert_injection" {
  name      = "vault_ssh_cert_cred_store"
  address   = var.vault_address
  namespace = vault_namespace.boundary.id
  token     = vault_token.boundary_ssh_token.client_token
  scope_id  = boundary_scope.proj.id
}

resource "boundary_credential_library_vault_ssh_certificate" "vault_ssh_cert" {
  name                = "vault_ssh_cert_library"
  credential_store_id = boundary_credential_store_vault.vault_ssh_cert_injection.id
  path                = "${vault_mount.ssh.id}/sign/${vault_ssh_secret_backend_role.boundary.name}"
  username            = var.ssh_username
  key_type            = "ecdsa"
  key_bits            = 521
  extensions = {
    permit-pty = ""
  }
}

resource "boundary_target" "ec2_ssh_cert_injection" {
  scope_id                                   = boundary_scope.proj.id
  name                                       = "ec2 ssh cert injection target"
  type                                       = "ssh"
  session_connection_limit                   = -1
  default_port                               = 22
  address                                    = aws_instance.boundary_target.private_ip
  injected_application_credential_source_ids = [boundary_credential_library_vault_ssh_certificate.vault_ssh_cert.id]
#  ingress_worker_filter                      = "\"sm-ingress-upstream-worker1\" in \"/tags/type\""
  egress_worker_filter                       = "\"sm-ingress-upstream-worker1\" in \"/tags/type\""
  #  enable_session_recording                   = true
  #  storage_bucket_id                          = boundary_storage_bucket.s3.id
}

### END: SSH Certification Injection Configuration ###