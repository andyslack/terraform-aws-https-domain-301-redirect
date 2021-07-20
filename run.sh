#! /bin/bash
set -euo pipefail

info() {
  printf "\r\033[00;35m$1\033[0m\n"
}

success() {
  printf "\r\033[00;32m$1\033[0m\n"
}

fail() {
  printf "\r\033[0;31m$1\033[0m\n"
}

divider() {
  printf "\r\033[0;1m========================================================================\033[0m\n"
}

pause_for_confirmation() {
  read -rsp $'Press any key to continue (ctrl-c to quit):\n' -n1 key
}

# Set up an interrupt handler so we can exit gracefully
interrupt_count=0
interrupt_handler() {
  ((interrupt_count += 1))

  echo ""
  if [[ $interrupt_count -eq 1 ]]; then
    fail "Really quit? Hit ctrl-c again to confirm."
  else
    echo "Goodbye!"
    exit
  fi
}
trap interrupt_handler SIGINT SIGTERM

# This setup script does all the magic.

# Check for required Terraform version
if ! terraform version -json | jq -r '.terraform_version' &> /dev/null; then
  echo
  fail "Terraform 0.13 or later is required for this setup script!"
  echo "You are currently running:"
  terraform version
  exit 1
fi

# Set up some variables we'll need
HOST="${1:-app.terraform.io}"
BACKEND_TF=$(dirname ${BASH_SOURCE[0]})/backend.tf
PROVIDER_TF=$(dirname ${BASH_SOURCE[0]})/provider.tf
REDIRECT_TF=$(dirname ${BASH_SOURCE[0]})/redirects.tf
TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')

# Check that we've already authenticated via Terraform in the static credentials
# file.  Note that if you configure your token via a credentials helper or any
# other method besides the static file, this script will not take that in to
# account - but we do this to avoid embedding a Go binary in this simple script
# and you hopefully do not need this Getting Started project if you're using one
# already!
CREDENTIALS_FILE="$HOME/.terraform.d/credentials.tfrc.json"
TOKEN=$(jq -j --arg h "$HOST" '.credentials[$h].token' $CREDENTIALS_FILE)
if [[ ! -f $CREDENTIALS_FILE || $TOKEN == null ]]; then
  fail "We couldn't find a token in the Terraform credentials file at $CREDENTIALS_FILE."
  fail "Please run 'terraform login', then run this setup script again."
  exit 1
fi

printf "\r\033[00;35;1m
--------------------------------------------------------------------------
Setup a domain redirect
-------------------------------------------------------------------------\033[0m"
echo
info "Are you ready to get started? Ctrl+c at any time to quit."
echo
echo "What domain name would you like to redirect FROM? (domain1.com)"
read REDIRECT_SOURCE
echo "What domain name would you like to redirect TO? (domain2.com)"
read REDIRECT_TARGET
divider
echo
info "Please confirm you would like to redirect $REDIRECT_SOURCE to $REDIRECT_TARGET"
echo
pause_for_confirmation

divider

WORKSPACE_NAME_TEMP="${REDIRECT_SOURCE}_redirect_${REDIRECT_TARGET}"
WORKSPACE_NAME="${WORKSPACE_NAME_TEMP//./_}"

printf "\r\033[00;35;1m
--------------------------------------------------------------------------
Workspace: $WORKSPACE_NAME
-------------------------------------------------------------------------\033[0m"
echo

# We don't sed -i because MacOS's sed has problems with it.
TEMP=$(mktemp)
cat $BACKEND_TF |
  # add backend config for the hostname if necessary
  if [[ "$HOST" != "app.terraform.io" ]]; then sed "5a\\
\    hostname = \"$HOST\"
    "; else cat; fi |
  # replace the organization and workspace names
  sed "s/{{WORKSPACE_NAME}}/${WORKSPACE_NAME}/" \
    > $TEMP
mv $TEMP $BACKEND_TF

echo "{{WORKSPACE_NAME}} replaced with $WORKSPACE_NAME"

# We don't sed -i because MacOS's sed has problems with it.
TEMP_RED=$(mktemp)
cat $REDIRECT_TF |

  # replace the domain redirect names
  sed "s/{{REDIRECT_SOURCE}}/${REDIRECT_SOURCE}/" |
  sed "s/{{REDIRECT_TARGET}}/${REDIRECT_TARGET}/" \
    > $TEMP_RED
mv $TEMP_RED $REDIRECT_TF

echo "{{REDIRECT_SOURCE}} replaced with $REDIRECT_SOURCE"
echo "{{REDIRECT_TARGET}} replaced with $REDIRECT_TARGET"

# add extra provider config for the hostname if necessary
if [[ "$HOST" != "app.terraform.io" ]]; then
  TEMP=$(mktemp)
  cat $PROVIDER_TF |
    sed "11a\\
  \  hostname = var.provider_hostname
      " \
      > $TEMP
  echo "
variable \"provider_hostname\" {
  type = string
}" >> $TEMP
  mv $TEMP $PROVIDER_TF
fi

#echo "$ terraform workspace new ${workspace_name}"
#terraform workspace new example $workspace_name

echo "$ terraform init -reconfigure"
terraform init -reconfigure

#divider
#echo "$ terraform plan"
#terraform plan

divider
echo "$ terraform apply -auto-approve"
terraform apply -auto-approve

printf "\r\033[00;35;1m
--------------------------------------------------------------------------
Cleanup and reset files
-------------------------------------------------------------------------\033[0m"
echo

FILE="$(dirname ${BASH_SOURCE[0]})/.terraform.lock.hcl"
if [ -f $FILE ]; then
   rm -rf $FILE
   echo "$FILE is removed"
fi

FILE="$(dirname ${BASH_SOURCE[0]})/.terraform/terraform.tfstate"
if [ -f $FILE ]; then
   rm -rf $FILE
   echo "$FILE is removed"
fi

DIRECTORY="$(dirname ${BASH_SOURCE[0]})/.terraform/modules/main"
if [ -d $DIRECTORY ]; then
   rm -rf $DIRECTORY
   echo "$DIRECTORY is removed"
fi

TEMP=$(mktemp)
cat $BACKEND_TF |
  # add backend config for the hostname if necessary
  if [[ "$HOST" != "app.terraform.io" ]]; then sed "5a\\
\    hostname = \"$HOST\"
    "; else cat; fi |
  # replace the organization and workspace names
  sed "s/${WORKSPACE_NAME}/{{WORKSPACE_NAME}}/" \
    > $TEMP
mv $TEMP $BACKEND_TF

echo "$WORKSPACE_NAME replaced with {{WORKSPACE_NAME}}"

TEMP_RED=$(mktemp)
cat $REDIRECT_TF |

  # replace the domain redirect names
  sed "s/${REDIRECT_SOURCE}/{{REDIRECT_SOURCE}}/" |
  sed "s/${REDIRECT_TARGET}/{{REDIRECT_TARGET}}/" \
    > $TEMP_RED
mv $TEMP_RED $REDIRECT_TF

echo "$REDIRECT_SOURCE replaced with {{REDIRECT_SOURCE}}"
echo "$REDIRECT_TARGET replaced with {{REDIRECT_TARGET}}"

success "All done :)"

echo -e "\a"

exit 0
