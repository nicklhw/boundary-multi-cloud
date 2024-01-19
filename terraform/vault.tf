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
  policies          = [vault_policy.boundary-controller.name, vault_policy.ssh.name]
  no_parent         = true
  period            = "20m"
  renewable         = true
}

resource "vault_ssh_secret_backend_ca" "ca" {
  namespace            = vault_namespace.boundary.path
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}
### END: SSH Certification Injection Configuration ###