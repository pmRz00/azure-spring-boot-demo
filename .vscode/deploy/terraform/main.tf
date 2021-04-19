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