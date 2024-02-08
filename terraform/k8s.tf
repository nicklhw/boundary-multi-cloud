resource "azurerm_kubernetes_cluster" "boundary_target" {
  name                = "boundary-aks-target"
  location            = azurerm_resource_group.boundary_demo.location
  resource_group_name = azurerm_resource_group.boundary_demo.name
  dns_prefix          = "boundary-demo"
  # This config makes the K8s API server private, but we cannot do this because
  # we need public access to the K8s API in order to create service account
  # for Vault
  # private_cluster_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
    # The ID of a Subnet where the Kubernetes Node Pool should exist.
    vnet_subnet_id = azurerm_subnet.private.id
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.10.2.0/24"
    dns_service_ip = "10.10.2.10"
  }

  identity {
    type = "SystemAssigned"
  }
}

### BEGIN: K8s Configuration ###
# https://www.hashicorp.com/blog/how-to-connect-to-kubernetes-clusters-using-boundary

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.boundary_target.kube_config.0.host
  username               = azurerm_kubernetes_cluster.boundary_target.kube_config.0.username
  password               = azurerm_kubernetes_cluster.boundary_target.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.boundary_target.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.boundary_target.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.boundary_target.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault"
    namespace = "vault"
  }
}

resource "kubernetes_secret_v1" "vault" {
  metadata {
    name      = "vault-sa-token"
    namespace = "vault"
    annotations = {
      "kubernetes.io/service-account.name" = "vault"
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role" "vault" {
  metadata {
    name = "k8s-full-secrets-abilities-with-labels"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "serviceaccounts/token"]
    verbs      = ["create", "update", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings", "clusterrolebindings"]
    verbs      = ["create", "update", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "clusterroles"]
    verbs      = ["bind", "escalate", "create", "update", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "vault" {
  metadata {
    name = "vault-token-creator-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "k8s-full-secrets-abilities-with-labels"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = "vault"
  }
}

### END: K8s Configuration ###

### BEGIN: Vault K8s Secrets Engine Configuration ###

resource "vault_kubernetes_secret_backend" "demo" {
  namespace            = vault_namespace.boundary.path
  path                 = "kubernetes"
  kubernetes_host      = azurerm_kubernetes_cluster.boundary_target.kube_config.0.host
  kubernetes_ca_cert   = base64decode(azurerm_kubernetes_cluster.boundary_target.kube_config.0.cluster_ca_certificate)
  service_account_jwt  = kubernetes_secret_v1.vault.data.token
  disable_local_ca_jwt = false
}

resource "vault_kubernetes_secret_backend_role" "demo" {
  namespace                     = vault_namespace.boundary.path
  backend                       = vault_kubernetes_secret_backend.demo.path
  name                          = "auto-managed-sa-and-role"
  allowed_kubernetes_namespaces = ["*"]
  token_max_ttl                 = 43200
  token_default_ttl             = 21600
  kubernetes_role_type          = "Role"
  generated_role_rules          = <<EOF
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "get", "create", "update", "delete", "watch"]
EOF
}

resource "vault_kv_secret_v2" "k8s_secret" {
  namespace = vault_namespace.boundary.path
  mount     = vault_mount.kv.path
  name      = "k8s-cluster"
  data_json = jsonencode(
    {
      "data" : {
        "ca_crt" : base64decode(azurerm_kubernetes_cluster.boundary_target.kube_config.0.cluster_ca_certificate)
      }
    }
  )
}

resource "vault_policy" "kubernetes_secrets" {
  namespace = vault_namespace.boundary.path
  name      = "kubernetes_secrets"
  policy    = <<EOT
path "kubernetes/creds/auto-managed-sa-and-role" {
  capabilities = ["update"]
}
path "secrets/data/k8s-cluster" {
 capabilities = ["read"]
}
EOT
}

### END: Vault K8s Secrets Engine Configuration ###

### BEGIN: Boundary K8s Target Configuration ###

resource "boundary_credential_library_vault" "k8s_sa_token" {
  name                = "kubernetes-sa-token-cred-lib"
  description         = "Kubernetes Service Account Token Credential library"
  credential_store_id = boundary_credential_store_vault.vault_cred_store.id
  path                = "${vault_kubernetes_secret_backend.demo.path}/creds/${vault_kubernetes_secret_backend_role.demo.name}"
  http_method         = "POST"
  http_request_body   = "{\"kubernetes_namespace\": \"default\"}"
}

resource "boundary_credential_library_vault" "k8s_ca" {
  name                = "kubernetes-ca-cert-cred-lib"
  description         = "Kubernetes CA Certificate Credential Library"
  credential_store_id = boundary_credential_store_vault.vault_cred_store.id
  path                = "${vault_mount.kv.path}/data/${vault_kv_secret_v2.k8s_secret.name}"
  http_method         = "GET"
}

resource "boundary_target" "k8s" {
  type        = "tcp"
  name        = "AKS Cluster"
  description = "My AKS Cluster"
  address     = azurerm_kubernetes_cluster.boundary_target.fqdn
  # Can optionally egress thru the self managed worker since Azure allows default outbound internet access
  # egress_worker_filter     = "\"sm-ingress-upstream-worker1\" in \"/tags/type\""
  scope_id                 = boundary_scope.proj.id
  session_connection_limit = -1
  default_port             = 443
  brokered_credential_source_ids = [
    boundary_credential_library_vault.k8s_sa_token.id,
    boundary_credential_library_vault.k8s_ca.id
  ]
}

### END: Boundary K8s Target Configuration ###