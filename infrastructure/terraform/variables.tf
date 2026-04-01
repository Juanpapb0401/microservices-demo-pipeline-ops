variable "project" {
  description = "Short project slug used for naming Azure resources."
  type        = string
  default     = "taller"
}

variable "location" {
  description = "Azure region where resources are provisioned."
  type        = string
  default     = "eastus2"
}

variable "node_count" {
  description = "Default node count for the AKS system node pool."
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "VM size for the AKS system node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "sku_tier" {
  description = "AKS pricing tier. Use Free for academic/lab environments."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size for AKS nodes. Lower values reduce cost."
  type        = number
  default     = 30
}
