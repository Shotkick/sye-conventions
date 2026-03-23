#!/bin/bash

#set -euo pipefail

set -x
trap 'echo "[TRAP] Error on line $LINENO: command=\"$BASH_COMMAND\" exit_code=$?' ERR
trap 'echo "[TRAP] Executing line $LINENO: $BASH_COMMAND"' DEBUG
printf "[DEBUG] Debug mode enabled\n"

#Check if script is run by root user
if [[ $EUID -ne 0 ]]; then
  printf "[ERROR] This script must be run as root." >&2 #redirect to stderr
  exit 1
fi

declare -A USER_KEYS=(
  [eval]="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrSzwPD9dq7Z10/MmKB/HWGObftj02F9FsdKN5QqLUG lecturer@insy-eval"
  [djordjevic]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9EFYu4SpUmaqLPhMlc2C3TdJhtbUqN/x8L9XUegnoxYo9OLdRmHQTIEuK7FpCatmYduInK4JzOB422gtnAOAgvwNN9/gsIdylcLBLnBtYNEKPUr8VR+PheMd3Q3MnV7wSd3oDXhntoRr9tDyvF+uNGXVArexnlNMRecHuNJQKI6+44CZQLiUOXMS3qyOFJ9o17EDmC8zIt0UwBskKuOzvi8t3uneVWvvxQLExXWES2vX3qwwmO1VN9XgmpglfW/MGp5QWfOMEzBF0iph0hzfyCxqISbf8BAVxGKzzcKQCSEDFO1x32cBkXIR8cniUcYqyCgz6y8LvTvcZchp1k0lx+WWsByHYyDX9Vty9PVRZkvvcVznRgY857/ueYj/bW6Mccprmd6FQ6ZrsbuGi4UWDJG7ok71AoreoZA1qHHVP2BUaYe60mjz7aDmOZ1KBl2oQznRqxO5c5nmczqtyW1vYwcb5gEFviSRkZMSMrbljkBnEVARbwCo0TdRsqtSfyThUfpLudzdtXzWsNcE1jZlW2KYQgqrRdVeSImn1slmjbT3VaJPcFN0GnaR7ThA9TIHizmxB+LN9I4RNxTVHNdOVGv7xD7voxZ2b6q2L+1BItnDTxCr7vXgZB/lGmR+XjF42mQCMYEmKexIW+P3Iv0BUtbi8uEaf/v8RLUmEMlAIZw== insy-switch-engines"
  [beldi]="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCgzome8dtFa1rxKLKct44g4fZaLHu5WL4rbpVlb4Vl9fVsCVwzDSkfMWGL3FDlGHafLEXWXUFprevh7liTZDu3aLriT3Z4Cq61JH6AG/b5w+5YC2he/HZeqO65oaKMnG0aLorn0kd2RmcFNde2rYjhyxQgngrhgtnjJ10szwxP60lkmvV7zeq5syiUGe8xZQe6rNNYbwJ1zk2I6TbU0u6HmCtcDixH9b2lDMxBD2ETz/aPfMb7Zd5kiwT+aHEVD6YBlg6fuFqMB5PUtyMJHT4WCikhkwQ/HngrLdJVNraDEJFrEWnwv/yKnrbwNYg2xgPekwM3hl4PuL8j5iwbZ63mvY6sW5yBsgvOg1A6ZjY96CXFoZ0VVlLs2vzq1mYoTEwraBXQHmI9hXWKJVBaBMw1reZ2q+PVjMwL4pTTpoOaCFihnicENrhi726Bs1qPNt+7uh+0PhvV3IcKzUk6OBrCmuT7EV6EHG/EsmS4LzIQ/jDLVr3l3S4wAJyUcFX2MgMNsmN/Y+KLsJG6OqDpnN1q+T7CIx3Q4lu3VwlNX6o+iYV+1lLn0M81SLl5KZEfGkNeiI3nU+cL8IRlyDPp3Bga4c2p+nQBRxbP6eg3JeRCugMjGuWvaCGi/P5wRX95ezjk4488oivRVdNxYeLxvIm8/zGgoIaQ69T9yS1h+XnVVw== insy-switch-engines"
)

DELETE_USER="debian"

createUser(){
    local username="$1"
    if userExists "$username"; then
        printf "SKIP  $username already exists\n"
    else
        printf "Creating $username:\n"
        adduser "$username"
        printf "OK  $username has been created\n"
    fi
}

userExists() {
    local username="$1"
    id "$username" &>/dev/null
}

addSudoUser(){
    local username="$1"
    local sudoersFile="/etc/sudoers.d/${username}"
    local sudoersLine="${username} ALL=(ALL) NOPASSWD:ALL"

    if [[ -f "$sudoersFile" ]] && grep -qF "$sudoersLine" "$sudoersFile"; then
        printf "SKIP  $username is already added in sudoers file\n"
    else
        echo "djordjevic ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/djordjevic > /dev/null
        chmod 0440 "$sudoersFile"
        printf "OK  $username sudoers file has been added\n"
    fi
}

setupUserSSH(){
    local username="$1"
    local key="$2"
    local sshDir="/home/${username}/.ssh"
    local authKeys="${sshDir}/authorized_keys"

    if [[ ! -d "$sshDir" ]]; then
        mkdir -p "$sshDir" #-p checks and creates parent folders if not existent
        printf "OK  .ssh directory for $username has been created\n"
    fi
    chmod 700 "$sshDir"
    chown "${username}:${username}" "$sshDir"

    if [[ -f "$authKeys" ]] && grep -qF "$key" "$authKeys"; then
        printf "SKIP  SSH key for $username already in authorized_keys\n"
    else
        echo "$pubkey" >> "$authKeys"
        printf "OK  Added SSH key for $username.\n"
    fi

    chmod 600 "$authKeys"
    chown "${username}:${username}" "$authKeys"
}

deleteUser(){
    local username="$1"
    if userExists "$username"; then
        deluser --remove-home $username
        printf "OK  User $username has been deleted\n"
    else
        printf "SKIP  User $username doesn't exist"
    fi
}

for username in "${!USER_KEYS[@]}"; do #! = keys, not values
    createUser "$username"
    addSudoUser "$username"
    setupUserSSH "$username" ${USER_KEYS[$username]}
done
printf "\n"

#deleteUser "$DELETE_USER"