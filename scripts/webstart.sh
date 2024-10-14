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

REPO_URL="https://github.com/munnotubbel/ententeich"
ZIP_URL="${REPO_URL}/archive/refs/heads/main.zip"
TARGET_DIR="ententeich"
ZIP_FILE="ententeich.zip"

print_fancy "Downloading repository as ZIP..." "yellow" "[INFO]"
if curl -L -o "$ZIP_FILE" "$ZIP_URL"; then
    print_fancy "Repository ZIP downloaded successfully." "green" "[SUCCESS]"
    
    print_fancy "Extracting ZIP file..." "yellow" "[INFO]"
    if unzip -q "$ZIP_FILE" -d "$TARGET_DIR"; then
        print_fancy "ZIP file extracted successfully." "green" "[SUCCESS]"
        
        rm "$ZIP_FILE"
        print_fancy "ZIP file removed." "green" "[INFO]"
        
        cd "$TARGET_DIR"/*
        
        if [ -d "scripts" ]; then
            cd scripts
            print_fancy "Changed to scripts directory." "green" "[SUCCESS]"
            
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
            print_fancy "Error: scripts directory not found." "red" "[ERROR]"
            exit 1
        fi
    else
        print_fancy "Error extracting ZIP file." "red" "[ERROR]"
        exit 1
    fi
else
    print_fancy "Error downloading repository ZIP." "red" "[ERROR]"
    exit 1
fi