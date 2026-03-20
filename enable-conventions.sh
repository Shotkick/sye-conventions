#!/bin/bash

#Check if script is run by root user
[[ $EUID -eq 0 ]] || die "This script must be run as root (use sudo)."

USERS_TO_CREATE_PATH="users_to_create.conf"
USER_TO_REMOVE=debian
declare -A USERS_TO_CREATE #-A = associative Array

while IFS='=' read -r key value; do
    # Skip empty lines or lines starting with #
    [[ -z "$key" || "$key" =~ ^# ]] && continue

    config_table["$key"]="$value"
    echo "info: User $key read"
done < "$file"