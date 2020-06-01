#!/bin/bash

## This script starts the genesis vault for a section


# ****************************** The following can be modified as needed **********************************************

# 0 => No user interaction. The script will use the values set in the config variable below or defaults in some cases.
# 1 => User interaction turned on. The script will ask the values from the user in an interactive fashion.
INTERACTIVE=0;
# ------ Config options: Modify these to change the defaults and specially if using the non-interactive mode ------
# 0 => No debug output from the script.
# 1 => Debug output from the script.
DEBUG=1;
# Interval in seconds between starting of the vaults.
INTERVAL_BETWEEN_VAULTS=15;
# Path to the directory in which the vault data will be stored.
VAULT_ROOT_DIR="./vault_data"
# Path to the vault executable file. This should include the file name too, not just the path to the directory as no
# assumption is made on the name of the executable (and hence must be provided by the user).
VAULT_EXE="./safe_vault";
# Vebosity level for vault logs.
# <blank> => log error.
# -v      => log error, warn.
# -vv     => log error, warn, info.
# -vvv    => log error, warn, info, debug.
# -vvvv   => log error, warn, info, debug, trace.
VAULT_LOGGING_VERBOSITY="-vvvv";
# 0 => Copies vault binary to the droplet
# 1 => Does not copy the vault binary
COPY_VAULT_BINARY=0

# *********************************************************************************************************************
# *********************************************************************************************************************

# Read the list of IPs of the remote machines from the `ip_list` file.
IP_LIST=()
while IFS= read -r line
do
  IP_LIST+=(${line})
done < ip_list

if [[ ${INTERACTIVE} != 0 ]]; then
    read -p "Full path to safe_vault executable [default = ${VAULT_EXE}]: " VAULT_EXE_INPUT;
    if [[ "${VAULT_EXE_INPUT}" != "" ]]; then
        VAULT_EXE="${VAULT_EXE_INPUT}";
    fi
fi

if [[ ${DEBUG} != 0 ]]; then
    printf 'Running genesis vault: %s\n' "${VAULT_EXE}";
fi

ssh root@${IP_LIST[0]} 'mkdir -p /home/safe; killall -9 safe_vault;'
if [[ ${COPY_VAULT_BINARY} == 0 ]]; then
    scp ${VAULT_EXE} root@${IP_LIST[0]}:/home/safe
fi
ssh root@${IP_LIST} "bash -s" < start-genesis-vault.bash ${IP_LIST[0]} ${VAULT_ROOT_DIR} ${VAULT_LOGGING_VERBOSITY} > connection_info
cp connection_info ~/.config/safe_vault/vault_connection_info.config
hcc=$(cat connection_info)
#Convert it into an array
hcc="[${hcc}]";
echo "Genesis vault running on ${IP_LIST[0]}"

ip_list_len=${#IP_LIST[@]}
for (( i = 1; i < ip_list_len; i++ )); do
    if [[ ${DEBUG} != 0 ]]; then
        printf '\nRunning vault number: %d in... ' $(($i + 1));
    fi
    for((j=${INTERVAL_BETWEEN_VAULTS}; j > 0; --j)); do
        if [[ ${DEBUG} != 0 ]]; then
            printf '%d ' ${j};
        fi
        sleep 1;
    done
    ssh root@${IP_LIST[i]} 'mkdir -p /home/safe; killall -9 safe_vault > /dev/null'
    if [[ ${COPY_VAULT_BINARY} == 0 ]]; then
        scp ${VAULT_EXE} root@${IP_LIST[i]}:/home/safe
    fi
    ssh root@${IP_LIST[i]} "bash -s" < start-new-vault.bash ${VAULT_ROOT_DIR} ${hcc@Q} ${VAULT_LOGGING_VERBOSITY}
done
