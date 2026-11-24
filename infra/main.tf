terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81.0"
    }
  }

  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
    container_name   = "tfstate"
    key              = "lab.tfstate"
  }
}

provider "azurerm" {
  features {}
  use_oidc                        = true
  storage_use_azuread             = true
  resource_provider_registrations = "none"
}

variable "app_container_id" {
  description = "ID ARM completo del contenedor privado app-config."
  type        = string

  validation {
    condition     = endswith(var.app_container_id, "/blobServices/default/containers/app-config")
    error_message = "Indica el ID ARM del contenedor app-config."
  }
}

resource "azurerm_storage_blob" "appsettings" {
  name                 = "appsettings.json"
  storage_container_id = var.app_container_id
  type                 = "Block"
  content_type         = "application/json"
  source_content       = file("${path.module}/../config/appsettings.json")
}
