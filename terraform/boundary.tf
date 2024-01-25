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
resource "boundary_credential_store_vault" "vault_cred_store" {
  name      = "vault_cred_store"
  address   = var.vault_address
  namespace = vault_namespace.boundary.id
  token     = vault_token.boundary_ssh_token.client_token
  scope_id  = boundary_scope.proj.id
}

resource "boundary_credential_library_vault_ssh_certificate" "vault_ssh_cert" {
  name                = "vault_ssh_cert_library"
  credential_store_id = boundary_credential_store_vault.vault_cred_store.id
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
  egress_worker_filter                       = "\"sm-ingress-upstream-worker1\" in \"/tags/type\""
  enable_session_recording                   = true
  storage_bucket_id                          = boundary_storage_bucket.boundary_aws_bucket.id
}

### END: SSH Certification Injection Configuration ###

### BEGIN: Session Recording Configuration ###

resource "boundary_storage_bucket" "boundary_aws_bucket" {
  name        = "hcpb-session-recording-bucket"
  scope_id    = "global"
  plugin_name = "aws"
  bucket_name = var.s3_bucket_name
  attributes_json = jsonencode({
    "region"                      = data.aws_region.current.name,
    "disable_credential_rotation" = true
  })

  secrets_json = jsonencode({
    "access_key_id"     = aws_iam_access_key.boundary_bsr.id,
    "secret_access_key" = aws_iam_access_key.boundary_bsr.secret
  })
  worker_filter = " \"sm-ingress-upstream-worker1\" in \"/tags/type\" "
}

/* Add a time_sleep to ensure that the Boundary worker has time to register with the controllers
and be in an active state. The boundary_storage_bucket needs to have an active worker when
you configure the worker_filter to specify which target you wish to use. If you do not have
an active worker, the build will fail
*/
#resource "time_sleep" "wait_for_ingress_worker_creation" {
#  create_duration = "3m"
#  depends_on      = [aws_instance.boundary_ingress_worker]
#}

### END: Session Recording Configuration ###

### BEGIN: Database Credential Brokering Configuration ###

resource "boundary_credential_library_vault" "postgres_dba" {
  name                = "northwind dba"
  description         = "northwind dba"
  credential_store_id = boundary_credential_store_vault.vault_cred_store.id
  path                = "database/creds/dba"
  http_method         = "GET"
}

resource "boundary_host_catalog_static" "aws_instance" {
  name        = "db-catalog"
  description = "DB catalog"
  scope_id    = boundary_scope.proj.id
}

resource "boundary_host_static" "db" {
  name            = "postgres-host"
  host_catalog_id = boundary_host_catalog_static.aws_instance.id
  address         = aws_instance.postgres_target.private_ip
}

resource "boundary_host_set_static" "db" {
  name            = "db-host-set"
  host_catalog_id = boundary_host_catalog_static.aws_instance.id
  host_ids = [
    boundary_host_static.db.id
  ]
}

resource "boundary_target" "dba" {
  type                     = "tcp"
  name                     = "Northwind DBA Database"
  description              = "DBA Target"
  egress_worker_filter     = "\"sm-ingress-upstream-worker1\" in \"/tags/type\""
  scope_id                 = boundary_scope.proj.id
  session_connection_limit = -1
  default_port             = 5432
  host_source_ids = [
    boundary_host_set_static.db.id
  ]
  # Comment this to avoid brokering the credentials
  brokered_credential_source_ids = [
    boundary_credential_library_vault.postgres_dba.id
  ]
}

### END: Database Credential Brokering Configuration ###

### BEGIN: RDP Credential Brokering Configuration ###

resource "boundary_credential_library_vault" "windows" {
  name                = "Vault KV"
  description         = "Vault KV"
  credential_store_id = boundary_credential_store_vault.vault_cred_store.id
  path                = "secrets/data/windows_secret"
  http_method         = "GET"
}

resource "boundary_host_catalog_static" "windows" {
  name        = "Windows Server"
  description = "Windows Server"
  scope_id    = boundary_scope.proj.id
}

resource "boundary_host_static" "windows" {
  name            = "windows-host"
  host_catalog_id = boundary_host_catalog_static.windows.id
  address         = aws_instance.windows_server.private_ip
}

resource "boundary_host_set_static" "windows" {
  name            = "windows-host-set"
  host_catalog_id = boundary_host_catalog_static.windows.id
  host_ids = [
    boundary_host_static.windows.id
  ]
}

resource "boundary_target" "win_rdp" {
  type                     = "tcp"
  name                     = "Windows RDP"
  description              = "RDP Target"
  scope_id                 = boundary_scope.proj.id
  session_connection_limit = -1
  egress_worker_filter     = "\"sm-ingress-upstream-worker1\" in \"/tags/type\""
  default_port             = 3389
  host_source_ids = [
    boundary_host_set_static.windows.id
  ]
  brokered_credential_source_ids = [
    boundary_credential_library_vault.windows.id
  ]
}

### END: RDP Credential Brokering Configuration ###