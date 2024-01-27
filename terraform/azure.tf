resource "azurerm_resource_group" "boundary_demo" {
  name     = "${var.prefix}-rg"
  location = var.azure_location
}

resource "azurerm_virtual_network" "boundary_demo" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.boundary_demo.location
  address_space       = [var.azure_vnet_address_space]
  resource_group_name = azurerm_resource_group.boundary_demo.name
}

resource "azurerm_subnet" "public" {
  name                 = "${var.prefix}-public-subnet"
  resource_group_name  = azurerm_resource_group.boundary_demo.name
  virtual_network_name = azurerm_virtual_network.boundary_demo.name
  address_prefixes     = [var.azure_public_subnet_cidr]
}

resource "azurerm_subnet" "private" {
  name                 = "${var.prefix}-private-subnet"
  resource_group_name  = azurerm_resource_group.boundary_demo.name
  virtual_network_name = azurerm_virtual_network.boundary_demo.name
  address_prefixes     = [var.azure_private_subnet_cidr]
}

resource "azurerm_network_security_group" "boundary_ingress_worker_sg" {
  name                = "${var.prefix}-ingress-worker-sg"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.boundary_demo.name

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "boundary_control_plane"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9202"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "private_subnet_nic" {
  name                = "${var.prefix}-private-subnet-nic"
  location            = azurerm_resource_group.boundary_demo.location
  resource_group_name = azurerm_resource_group.boundary_demo.name
  ip_configuration {
    name                          = "${var.prefix}-private-subnet-nic-ipconfig"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate the Network Security Group to the Public Subnet
resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.boundary_ingress_worker_sg.id
}

resource "azurerm_windows_virtual_machine" "boundary_demo" {
  name                  = "boundary-rdp-target"
  computer_name         = "boundary-target"
  resource_group_name   = azurerm_resource_group.boundary_demo.name
  location              = azurerm_resource_group.boundary_demo.location
  size                  = "Standard_A2_v2"
  admin_username        = "adminuser"
  admin_password        = var.windows_admin_password
  network_interface_ids = [azurerm_network_interface.private_subnet_nic.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_network_security_group" "boundary_target_sg" {
  name                = "${var.prefix}-target-sg"
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.boundary_demo.name

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = azurerm_subnet.public.address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = azurerm_subnet.public.address_prefixes
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.boundary_target_sg.id
}