provider "azurerm" {
  features {}
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.66"
    }
  }
}

locals {
  rg_name        = "rg-${var.project}"
  aks_name       = "aks-${var.project}"
  aks_dns_prefix = "aks-${var.project}"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location

  tags = {
    project     = var.project
    environment = "shared"
    scope       = "single-aks"
    managed_by  = "terraform"
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = local.aks_dns_prefix
  sku_tier            = var.sku_tier

  default_node_pool {
    name       = "default"
    node_count = var.enable_cluster_autoscaling ? null : var.node_count
    auto_scaling_enabled = var.enable_cluster_autoscaling
    min_count  = var.enable_cluster_autoscaling ? var.min_node_count : null
    max_count  = var.enable_cluster_autoscaling ? var.max_node_count : null
    vm_size    = var.vm_size
    os_disk_size_gb = var.os_disk_size_gb
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    project     = var.project
    environment = "shared"
    scope       = "single-aks"
    managed_by  = "terraform"
  }
}