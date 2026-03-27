###############################################################################
# imports.tf
#
# If a previous partial apply already created resources that Terraform now
# needs to manage, run:
#   terraform import <address> <azure_resource_id>
#
# The commands below cover the DNS zones that may already exist from a prior
# apply. Run these BEFORE terraform apply if you hit "resource already exists".
#
# terraform import \
#   'module.traffic_manager.azurerm_private_dns_zone.london_view' \
#   '/subscriptions/<SUB_ID>/resourceGroups/<project>-rg-uksouth/providers/Microsoft.Network/privateDnsZones/postgres.<project>.internal'
#
# terraform import \
#   'module.traffic_manager.azurerm_private_dns_zone.sao_paulo_view' \
#   '/subscriptions/<SUB_ID>/resourceGroups/<project>-rg-brazilsouth/providers/Microsoft.Network/privateDnsZones/postgres.<project>.internal'
#
# Replace <SUB_ID> and <project> with your actual values, e.g. v0326.
# If the zones were created in the postgres RG (old location), delete them
# from the Azure portal first — they're now managed per-region RG.
###############################################################################
