TF_INFRA_SRC_DIR ?= ./terraform

.PHONY: tf-plan
tf-plan:
	terraform -chdir=$(TF_INFRA_SRC_DIR) init -upgrade
	terraform -chdir=$(TF_INFRA_SRC_DIR) plan

.PHONY: tf-apply
tf-apply:
	terraform -chdir=$(TF_INFRA_SRC_DIR) init -upgrade
	terraform -chdir=$(TF_INFRA_SRC_DIR) apply --auto-approve

.PHONY: tf-destroy
tf-destroy:
	terraform -chdir=$(TF_INFRA_SRC_DIR) destroy --auto-approve

.PHONY: hcp-console
hcp-console:
	open https://portal.cloud.hashicorp.com

.PHONY: tf-fmt
tf-fmt:
	terraform -chdir=$(TF_INFRA_SRC_DIR) fmt

# .PHONY: tf-rm
# tf-rm:
# 	terraform -chdir=$(TF_INFRA_SRC_DIR) state rm 'azurerm_kubernetes_cluster.boundary_target'
# 	terraform -chdir=$(TF_INFRA_SRC_DIR) state rm 'kubernetes_cluster_role.vault'
# 	terraform -chdir=$(TF_INFRA_SRC_DIR) state rm 'kubernetes_cluster_role_binding.vault'
# 	terraform -chdir=$(TF_INFRA_SRC_DIR) state rm 'kubernetes_namespace.vault'
# 	terraform -chdir=$(TF_INFRA_SRC_DIR) state rm 'kubernetes_secret_v1.vault'
# 	terraform -chdir=$(TF_INFRA_SRC_DIR) state rm 'kubernetes_service_account.vault'