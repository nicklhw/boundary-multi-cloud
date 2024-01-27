resource "boundary_worker" "az_ingress_pki_worker" {
  scope_id                    = "global"
  name                        = "az-boundary-ingress-pki-worker"
  worker_generated_auth_token = ""
}

locals {
  az_boundary_ingress_worker_hcl_config = <<-WORKER_HCL_CONFIG
  disable_mlock = true

  hcp_boundary_cluster_id = "${split(".", split("//", var.boundary_cluster_url)[1])[0]}"

  listener "tcp" {
    address = "0.0.0.0:9202"
    purpose = "proxy"
  }

  worker {
    public_addr = "file:///tmp/ip"
    auth_storage_path = "/etc/boundary.d/worker"
    recording_storage_path = "/etc/boundary.d/sessionrecord"
    controller_generated_activation_token = "${boundary_worker.az_ingress_pki_worker.controller_generated_activation_token}"
    tags {
      type = ["az-ingress-upstream-worker1"]
    }
  }
WORKER_HCL_CONFIG

  cloudinit_config_az_boundary_ingress_worker = {
    write_files = [
      {
        content = local.boundary_ingress_worker_service_config
        path    = "/etc/systemd/system/boundary.service"
      },

      {
        content = local.az_boundary_ingress_worker_hcl_config
        path    = "/etc/boundary.d/pki-worker.hcl"
      },
    ]
  }
}

data "cloudinit_config" "azure_boundary_ingress_worker" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - ;\
      sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" ;\
      sudo apt-get update && sudo apt-get install boundary-enterprise -y
      curl 'https://api.ipify.org?format=txt' > /tmp/ip
      sudo mkdir /etc/boundary.d/sessionrecord
  EOF
  }
  part {
    content_type = "text/cloud-config"
    content      = yamlencode(local.cloudinit_config_az_boundary_ingress_worker)
  }
  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #!/bin/bash
    sudo chown boundary:boundary -R /etc/boundary.d
    sudo chown boundary:boundary /usr/bin/boundary
    sudo systemctl daemon-reload
    sudo systemctl enable boundary
    sudo systemctl start boundary
    EOF
  }
}

resource "azurerm_linux_virtual_machine" "boundary_ingress_worker" {
  name                  = "boundary-ingress-worker"
  computer_name         = "boundary-ingress-worker"
  resource_group_name   = azurerm_resource_group.boundary_demo.name
  location              = azurerm_resource_group.boundary_demo.location
  size                  = "Standard_A2_v2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.public_subnet_nic.id]
  custom_data           = data.cloudinit_config.azure_boundary_ingress_worker.rendered

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_rsa_public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_public_ip" "boundary_ingress_worker_pub_ip" {
  name                = "${var.prefix}-ingress-worker-ip"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.boundary_demo.name
  allocation_method   = "Dynamic"
  domain_name_label   = var.prefix
}

resource "azurerm_network_interface" "public_subnet_nic" {
  name                = "${var.prefix}-public-subnet-nic"
  location            = azurerm_resource_group.boundary_demo.location
  resource_group_name = azurerm_resource_group.boundary_demo.name
  ip_configuration {
    name                          = "${var.prefix}-public-subnet-nic-ipconfig"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.boundary_ingress_worker_pub_ip.id
  }
}