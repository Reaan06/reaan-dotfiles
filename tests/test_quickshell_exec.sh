#!/bin/bash
export PATH=$PATH:/usr/bin:/bin
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
NETWORK_SCRIPTS=("/home/reaan/reaan-dotfiles/dot_config/scripts/network-manager.sh" "/home/reaan/reaan-dotfiles/dot_config/scripts/bt-manager.sh")
for script in "${NETWORK_SCRIPTS[@]}"; do
    echo "Executing $script"
    timeout 2s bash "$script" --status
done
ps -o pid,ppid,state,cmd --ppid $$
