###############################################################################
# modules/traffic_manager/main.tf
#
# Geo-aware PostgreSQL routing via split-horizon Private DNS.
#
# SINGLE FQDN:  postgres.<project>.internal
#
#   London VNet    → resolves to → primary FQDN  (uksouth,      read+write)
#   São Paulo VNet → resolves to → replica FQDN  (brazilsouth,  read-only)
#
# HOW IT WORKS:
#   Two Private DNS zones with the same name live in DIFFERENT resource groups
#   (one per region). Azure allows duplicate Private DNS zone names as long as
#   they are in different resource groups. Each zone is linked only to its
#   region's VNet, so Azure resolves the same name differently depending on
#   which VNet the DNS query originates from (split-horizon DNS).
#
# AVAILABLE FQDNs (resolve correctly from both VNets):
#   postgres.<project>.internal         → geo-local (primary from London,
#                                         replica from São Paulo)  ← use for reads
#   postgres-primary.<project>.internal → always London primary    ← use for writes
#   postgres-replica.<project>.internal → always São Paulo replica
###############################################################################

###############################################################################
# London DNS view
# Lives in the London resource group, linked only to the London VNet.
###############################################################################

resource "azurerm_private_dns_zone" "london_view" {
  name                = "postgres.${var.project_name}.internal"
  resource_group_name = var.resource_group_name_london   # London RG — unique scope
  tags                = merge(var.tags, { dns-view = "london" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "london_view" {
  name                  = "postgres-dns-london-view"
  private_dns_zone_name = azurerm_private_dns_zone.london_view.name
  resource_group_name   = var.resource_group_name_london
  virtual_network_id    = var.vnet_id_london
  registration_enabled  = false
  tags                  = var.tags
}

# Geo-local: London clients → primary (local, low-latency, read+write)
resource "azurerm_private_dns_cname_record" "geo_london" {
  name                = "postgres"
  zone_name           = azurerm_private_dns_zone.london_view.name
  resource_group_name = var.resource_group_name_london
  ttl                 = 60
  record              = var.primary_fqdn
}

resource "azurerm_private_dns_cname_record" "primary_alias_london" {
  name                = "postgres-primary"
  zone_name           = azurerm_private_dns_zone.london_view.name
  resource_group_name = var.resource_group_name_london
  ttl                 = 60
  record              = var.primary_fqdn
}

resource "azurerm_private_dns_cname_record" "replica_alias_london" {
  name                = "postgres-replica"
  zone_name           = azurerm_private_dns_zone.london_view.name
  resource_group_name = var.resource_group_name_london
  ttl                 = 60
  record              = var.replica_fqdn
}

###############################################################################
# São Paulo DNS view
# Lives in the São Paulo resource group, linked only to the São Paulo VNet.
###############################################################################

resource "azurerm_private_dns_zone" "sao_paulo_view" {
  name                = "postgres.${var.project_name}.internal"
  resource_group_name = var.resource_group_name_sao_paulo  # SP RG — unique scope
  tags                = merge(var.tags, { dns-view = "sao-paulo" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "sao_paulo_view" {
  name                  = "postgres-dns-sao-paulo-view"
  private_dns_zone_name = azurerm_private_dns_zone.sao_paulo_view.name
  resource_group_name   = var.resource_group_name_sao_paulo
  virtual_network_id    = var.vnet_id_sao_paulo
  registration_enabled  = false
  tags                  = var.tags
}

# Geo-local: São Paulo clients → replica (local, low-latency, read-only)
resource "azurerm_private_dns_cname_record" "geo_sao_paulo" {
  name                = "postgres"
  zone_name           = azurerm_private_dns_zone.sao_paulo_view.name
  resource_group_name = var.resource_group_name_sao_paulo
  ttl                 = 60
  record              = var.replica_fqdn
}

resource "azurerm_private_dns_cname_record" "primary_alias_sao_paulo" {
  name                = "postgres-primary"
  zone_name           = azurerm_private_dns_zone.sao_paulo_view.name
  resource_group_name = var.resource_group_name_sao_paulo
  ttl                 = 60
  record              = var.primary_fqdn
}

resource "azurerm_private_dns_cname_record" "replica_alias_sao_paulo" {
  name                = "postgres-replica"
  zone_name           = azurerm_private_dns_zone.sao_paulo_view.name
  resource_group_name = var.resource_group_name_sao_paulo
  ttl                 = 60
  record              = var.replica_fqdn
}
