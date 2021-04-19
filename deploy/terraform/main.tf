terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state"
    storage_account_name = "tostilletfstate"
    container_name       = "tfstate-azure-spring"
    key                  = "terraformazurespringclouddemo.tfstate"
  }
}
 
provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you're using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}

resource "azurerm_resource_group" "demo" {
  name     = "username"
  location = "westeurope"
}

resource "azurerm_application_insights" "demo" {
  name                = "tf-test-appinsights"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  application_type    = "web"
}

resource "azurerm_spring_cloud_service" "demo" {
  name                = "usernamesp"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  config_server_git_setting {
    uri          = "https://github.com/Azure-Samples/piggymetrics-config"
    label        = "master"
    search_paths = ["."]
  }

  trace {
    instrumentation_key = azurerm_application_insights.demo.instrumentation_key
    sample_rate         = 10.0
  }

  tags = {
    Env = "dev"
  }
}

resource "azurerm_storage_account" "demo" {
  name                     = "tostilleascdemo"
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