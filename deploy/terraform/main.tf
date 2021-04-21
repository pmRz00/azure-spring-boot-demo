terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.56.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "demo" {
  name     = "tostille-spring-cloud-demo"
  location = "northeurope"
}

resource "azurerm_spring_cloud_service" "demo" {
  name                = "tostillesp"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  config_server_git_setting {
    uri          = "https://github.com/Azure-Samples/piggymetrics-config"
    label        = "master"
    search_paths = ["."]
  }
}

resource "azurerm_storage_account" "demo" {
  name                     = "usernamest"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_monitor_diagnostic_setting" "demo" {
  name               = "demo"
  target_resource_id = "${azurerm_spring_cloud_service.demo.id}"
  storage_account_id = "${azurerm_storage_account.demo.id}"

  log {
    category = "SystemLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_virtual_network" "demo" {
  name                = "demo-network"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  address_space       = ["10.254.0.0/16"]
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.254.0.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.254.2.0/24"]
}

resource "azurerm_public_ip" "demo" {
  name                = "demo-pip"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  allocation_method   = "Dynamic"
}

#&nbsp;since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.demo.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.demo.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.demo.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.demo.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.demo.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.demo.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.demo.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "demo-appgateway"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.demo.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}