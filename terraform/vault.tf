resource "vault_namespace" "boundary" {
  path = var.prefix
}

resource "vault_policy" "boundary-controller" {
  namespace = vault_namespace.boundary.path
  name      = "boundary-controller"
  policy    = <<EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
path "sys/leases/renew" {
  capabilities = ["update"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
path "sys/capabilities-self" {
  capabilities = ["update"]
}
EOT
}

### BEGIN: SSH Certification Injection Configuration ###

resource "vault_mount" "ssh" {
  namespace = vault_namespace.boundary.path
  path      = "ssh-client-signer"
  type      = "ssh"
}

resource "vault_policy" "ssh" {
  namespace = vault_namespace.boundary.path
  name      = "ssh-client-signer"
  policy    = <<EOT
path "ssh-client-signer/issue/boundary-client" {
  capabilities = ["create", "update"]
}

path "ssh-client-signer/sign/boundary-client" {
  capabilities = ["create", "update"]
}
EOT
}

resource "vault_ssh_secret_backend_role" "boundary" {
  namespace               = vault_namespace.boundary.path
  name                    = "boundary-client"
  backend                 = vault_mount.ssh.path
  key_type                = "ca"
  allow_user_certificates = true
  default_user            = var.ssh_username
  default_extensions      = tomap({ "permit-pty" : "" })
  allowed_users           = "*"
  allowed_extensions      = "*"
}

resource "vault_token" "boundary_ssh_token" {
  namespace         = vault_namespace.boundary.path
  no_default_policy = true
  policies = [
    vault_policy.boundary-controller.name,
    vault_policy.ssh.name,
    vault_policy.northwind_database.name,
    vault_policy.windows_secret.name
  ]
  no_parent = true
  period    = "20m"
  renewable = true
}

resource "vault_ssh_secret_backend_ca" "ca" {
  namespace            = vault_namespace.boundary.path
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}
### END: SSH Certification Injection Configuration ###

### BEGIN: Database Credential Brokering Configuration ###

resource "vault_mount" "database" {
  namespace                 = vault_namespace.boundary.path
  path                      = "database"
  type                      = "database"
  default_lease_ttl_seconds = 300
  max_lease_ttl_seconds     = 3600
}

resource "vault_database_secret_backend_connection" "postgres" {
  namespace     = vault_namespace.boundary.path
  backend       = vault_mount.database.path
  name          = "postgres"
  allowed_roles = ["dba"]

  # Going towards the private IP of the Ubuntu Server
  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${aws_instance.postgres_target.private_ip}:5432/postgres?sslmode=disable"
    username       = "vault"
    password       = "vault-password"
  }
}

resource "vault_database_secret_backend_role" "dba" {
  namespace           = vault_namespace.boundary.path
  backend             = vault_mount.database.path
  name                = "dba"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = [file("templates/dba.sql.hcl")]
}

resource "vault_policy" "northwind_database" {
  namespace = vault_namespace.boundary.path
  name      = "northwind_database"
  policy    = <<EOT
path "database/creds/dba" {
  capabilities = ["read"]
}
EOT
}

### END: Database Credential Brokering Configuration ###

### BEGIN: RDP Credential Brokering Configuration ###

resource "vault_mount" "kv" {
  namespace   = vault_namespace.boundary.path
  path        = "secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "Key-Value Secrets Engine"
}

resource "vault_kv_secret_v2" "windows_secret" {
  namespace = vault_namespace.boundary.path
  mount     = vault_mount.kv.path
  name      = "windows_secret"
  data_json = jsonencode(
    {
      "data" : {
        "username" : "Administrator",
        "password" : var.windows_admin_password
      }
    }
  )
}

resource "vault_policy" "windows_secret" {
  namespace = vault_namespace.boundary.path
  name      = "windows_secret"
  policy    = <<EOT
path "secrets/data/windows_secret" {
  capabilities = ["read"]
}
path "secrets/metadata/windows_secret" {
  capabilities = ["read"]
}
EOT
}

### END: RDP Credential Brokering Configuration ###