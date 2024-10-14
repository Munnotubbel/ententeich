#!/bin/bash

set -e

source "./fancy.sh"

load_and_execute() {
    local script=$1
    if [ -f "$script" ]; then
        print_fancy "Executing $script" "green" "🚀"
        source "$script"
    else
        print_fancy "Warning: $script not found" "yellow" "⚠️"
    fi
}

print_fancy "Starting cleanup and reset process..." "green" "🧹"

print_fancy "Removing .git directories from microservices..." "yellow" "🗑️"
find ../microservices -name ".git" -type d -exec rm -rf {} +

print_fancy "Cleaning up OpenTofu directories..." "yellow" "🧽"
find ../opentofu -name ".terraform" -type d -exec rm -rf {} +
find ../opentofu -name "terraform.tfstate.backup" -type f -delete
find ../opentofu -name "terraform.tfstate" -type f -delete
find ../opentofu -name ".terraform.tfstate.lock.info" -type f -delete
find ../opentofu -name ".terraform.lock.hcl" -type f -delete

print_fancy "Destroying Kind cluster..." "red" "💥"
kind delete cluster

print_fancy "Cleanup completed. Starting setup process..." "green" "🔄"

load_and_execute "setup.sh"

print_fancy "Reset and setup process completed!" "green" "🎉"