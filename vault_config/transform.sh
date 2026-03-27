echo #VAULT ENVIRONMENT VARIABLES
#export VAULT_TOKEN=<YOUR_VAULT_TOKEN>
#export VAULT_NAMESPACE=root
#export VAULT_ADDR=<YOUR_VAULT_ADDRESS>
#export VAULT_SKIP_VERIFY=true
echo #Transform Engine Variables
export TRANSFORM_PATH_NAME=org
export TRANSFORM_ROLE_NAME=agent
echo #Tokenization Store Variables
#export POSTGRES_ADDR=v0326-psql-primary.postgres.database.azure.com:5432 # Esse funciona
export POSTGRES_ADDR=postgres.postgres.v0326.internal
export POSTGRES_DATABASE=vault
export POSTGRES_USERNAME=pgadmin
export POSTGRES_PASSWORD=CHANGE_ME_strong_password_123!

echo ###################### Vault Setup ######################
#Secret Engine
vault secrets enable -path=$TRANSFORM_PATH_NAME transform 

#Role
vault write $TRANSFORM_PATH_NAME/role/$TRANSFORM_ROLE_NAME \
 transformations=cpf,cnpj,ticket

echo #####################Templates ####################
#Custom Alphabets
  vault write $TRANSFORM_PATH_NAME/alphabet/general_email_alphabet \
    alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._%+-&ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÝàáâãäåçèéêëìíîïñòóôõöùúûýÿ"

#Transformation Templates
vault write $TRANSFORM_PATH_NAME/template/cnpj \
  type=regex \
  pattern='(\d{2})\.(\d{3})\.(\d{3})\/(\d{4})-(\d{2})' \
  deletion_allowed=true \
  alphabet=builtin/numeric

vault write $TRANSFORM_PATH_NAME/template/cpf \
  type=regex \
  pattern='(\d{3}).(\d{3}).(\d{3})-(\d{2})' \
  deletion_allowed=true \
  alphabet=builtin/numeric

echo ###################### FPE ########################
vault write $TRANSFORM_PATH_NAME/transformations/fpe/cpf \
  template=cpf \
  tweak_source=generated \
  deletion_allowed=true \
  allowed_roles=$TRANSFORM_ROLE_NAME

vault write $TRANSFORM_PATH_NAME/transformations/fpe/cnpj \
  template=cnpj \
  tweak_source=internal \
  deletion_allowed=true \
  allowed_roles=$TRANSFORM_ROLE_NAME

echo ###################### Tokenization external store ########################
export TOKEN_STORE_NAME=ticket_store
vault write /org/stores/$TOKEN_STORE_NAME name=$TOKEN_STORE_NAME type=sql \
connection_string="postgresql://{{username}}:{{password}}@$POSTGRES_ADDR/$POSTGRES_DATABASE" \
driver=postgres \
username=$POSTGRES_USERNAME \
password=$POSTGRES_PASSWORD \
supported_transformations=tokenization


vault write /org/stores/$TOKEN_STORE_NAME/schema username=$POSTGRES_USERNAME password=$POSTGRES_PASSWORD

vault read /org/stores/$TOKEN_STORE_NAME
echo ###################### Tokenization #######################
vault write $TRANSFORM_PATH_NAME/transformations/tokenization/ticket \
  convergent=false \
  stores="ticket_store" \
  deletion_allowed=true \
  allowed_roles=$TRANSFORM_ROLE_NAME

echo ###################### Test Tokenization #######################
vault write org/encode/agent value="HEllo World" transformation=ticket

vault write org/decode/agent value="Q4tYgFXHxUWm1ZgLQdzNdosQcWUtgNVbUPVbtmpFMCk8JattfkhN1u" transformation=ticket

