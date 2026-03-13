#Start by requesting Azure AD Developer access via Doormat: https://doormat.hashicorp.services/applications/access/az-ad-hashicorp02/role/doormat-azure-ad-hashicorp02-developer-access/options
#then request a temporary Azure Subscription: https://doormat.hashicorp.services/azure/subscription/temp/create

#using doormat web UI, login to the Azure Portal

# if you requested the correct AD Roles, the your tenant ID will be this
# az account clear
az login --tenant 237fbc04-c52a-458b-af97-eaf7157c0cd4 --use-device-code
# choose the correct subscription
#237fbc04-c52a-458b-af97-eaf7157c0cd4
#Tenant: 237fbc04-c52a-458b-af97-eaf7157c0cd4
#Subscription: guy-azure-20240930-test (02405acf-a75a-4a87-be6f-25943dc6cb6c)


AZURE_DETAILS=$(az account show)

export TF_VAR_subscription_id=$(echo $AZURE_DETAILS | jq -r .id)


terraform init

terraform plan

terraform apply

