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