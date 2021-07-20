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

printf "\r\033[00;35;1m
--------------------------------------------------------------------------
Cleanup
-------------------------------------------------------------------------\033[0m"
echo
info "What was the last domain you setup? Ctrl+c at any time to quit."
echo
echo "What domain name would you like to redirect FROM? (domain1.com)"
read REDIRECT_SOURCE
echo "What domain name would you like to redirect TO? (domain2.com)"
read REDIRECT_TARGET
divider

printf "\r\033[00;35;1m
--------------------------------------------------------------------------
Cleanup and reset files
-------------------------------------------------------------------------\033[0m"
echo

WORKSPACE_NAME_TEMP="${REDIRECT_SOURCE}_redirect_${REDIRECT_TARGET}"
WORKSPACE_NAME="${WORKSPACE_NAME_TEMP//./_}"

BACKEND_TF=$(dirname ${BASH_SOURCE[0]})/backend.tf
REDIRECT_TF=$(dirname ${BASH_SOURCE[0]})/redirects.tf

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
