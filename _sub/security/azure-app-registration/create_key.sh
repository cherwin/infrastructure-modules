# Exit if any of the intermediate steps fail
set -e


# Define varibales
CREATE_KEY=0
APPLICATION_ID=$1
KEY_PATH_S3=$2
CONFIG_DIR=$3

# Set config-dir
export AZURE_CONFIG_DIR="$HOME/.azure-$CONFIG_DIR"

# Login to Azure
az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID > /dev/null


# Determine if app key already exist in App Reg
NUM_KEYS_AZ=$(az ad sp credential list --id $APPLICATION_ID | jq length)
# NUM_KEYS_AZ=1 # debug
if [ $NUM_KEYS_AZ -eq 0 ]; then
    CREATE_KEY=1
fi


# Determine if key file exists in S3
aws s3 ls $KEY_PATH_S3 >/dev/null || CREATE_KEY=1


# Create new key
if [ $CREATE_KEY -eq 1 ]; then

    echo "No key found for app in Azure AD or key file not found in S3. Generating new."

#     OUTPUT="\
# {
#     \"appId\": \"$APPLICATION_ID\",
#     \"password\": \"$(date)\",
# }"
    
    az ad sp credential reset -n $APPLICATION_ID --years 100 | aws s3 cp - $KEY_PATH_S3 --content-type "application/json"

    # echo $OUTPUT | aws s3 cp - $KEY_PATH_S3 --content-type "application/json"

else

    echo "Not generating key."

fi