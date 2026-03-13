###############################################################################
# modules/log_analytics/main.tf
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

###############################################################################
# modules/log_analytics/variables.tf
###############################################################################

variable "name"                { type = string }
variable "location"            { type = string }
variable "resource_group_name" { type = string }
variable "tags"                { type = map(string) }

###############################################################################
# modules/log_analytics/outputs.tf
###############################################################################

output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "workspace_key" {
  value     = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive = true
}
