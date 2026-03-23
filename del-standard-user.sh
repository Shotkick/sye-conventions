#!/bin/bash

#set -euo pipefail

set -x
trap 'echo "[TRAP] Error on line $LINENO: command=\"$BASH_COMMAND\" exit_code=$?' ERR
trap 'echo "[TRAP] Executing line $LINENO: $BASH_COMMAND"' DEBUG
printf "DEBUG  Debug mode enabled\n"

#Check if script is run by root user
if [[ $EUID -ne 0 ]]; then
  printf "ERROR  This script must be run as root." >&2 #redirect to stderr
  exit 1
fi

DELETE_USER="debian"

deleteUser(){
    local username="$1"
    if userExists "$username"; then
        deluser --remove-home $username
        rm "/etc/sudoers.d/${username}"
        printf "OK  User $username has been deleted\n"
    else
        printf "SKIP  User $username doesn't exist"
    fi
}

deleteUser "$DELETE_USER"