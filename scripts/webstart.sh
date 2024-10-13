#!/bin/bash

print_fancy() {
    local message="$1"
    local color="$2"
    local prefix="$3"

    case "$color" in
        "green") color_code="\033[0;32m" ;;
        "yellow") color_code="\033[0;33m" ;;
        "red") color_code="\033[0;31m" ;;
        *) color_code="\033[0m" ;;
    esac

    echo -e "${color_code}${prefix} ${message}\033[0m"
}

REPO_URL="https://github.com/munnotubbel/ententeich.git"
TARGET_DIR="ententeich"

print_fancy "Cloning repository..." "yellow" "[INFO]"
git clone $REPO_URL $TARGET_DIR

if [ $? -eq 0 ]; then
    print_fancy "Repository cloned successfully." "green" "[SUCCESS]"
    
    cd $TARGET_DIR

    cd scripts

    if [ $? -eq 0 ]; then
        print_fancy "Successfully changed to /scripts directory." "green" "[SUCCESS]"
        
        if [ -f "setup.sh" ]; then
            print_fancy "Executing setup.sh..." "yellow" "[INFO]"
            bash setup.sh
            if [ $? -eq 0 ]; then
                print_fancy "setup.sh executed successfully." "green" "[SUCCESS]"
            else
                print_fancy "Error executing setup.sh." "red" "[ERROR]"
                exit 1
            fi
        else
            print_fancy "Error: setup.sh not found." "red" "[ERROR]"
            exit 1
        fi
    else
        print_fancy "Error: Could not change to /scripts directory." "red" "[ERROR]"
        exit 1
    fi
else
    print_fancy "Error cloning the repository." "red" "[ERROR]"
    exit 1
fi