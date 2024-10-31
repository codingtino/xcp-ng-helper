#!/bin/bash

############################################################
# Title: XCP-ng - Helper                                   #
# Author: Tino Naumann                                     #
# Repository: https://github.com/codingtino/xcp-ng-helper  #
############################################################



#/opt/xensource/libexec/xen-cmdline --set-dom0 „xen-pciback. hide=(04:00.0) (00:17.0)“
#systemctl disable chrony-wait.service

set -euo pipefail

# Set to "true" to allow duplicates, "false" to prevent duplicates
ALLOW_DUPLICATES="false"

# Function for Option 1
function disable_chrony_wait {
    if [[ systemctl disable chrony-wait.service ]]; then
        if [[ $(systemctl is-enabled chrony-wait.service) == "disabled" ]]; then
            echo "Disabled chrony-wait service successfully."
        else
            error_exit "Failed to disable chrony-wait service. It is still enabled."
        fi
    else
        error_exit "Could not issue the disable command for chrony-wait.service."
    fi
    echo ""
}

# Display an error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Function to display the menu
function show_menu {
    echo "Please choose an option:"
    echo "1) Disable chrony-wait Service at boot"
    echo "0) Exit"
}

# Execute the choice
function execute_choice {
    case "$1" in
        1) disable_chrony_wait ;;
        0) echo "Exiting..."; exit 0 ;;
        *) error_exit "Invalid option: $1" ;;
    esac
}

# Function to generate a comma-separated list of valid options
generate_valid_options() {
    local max="$1"
    local options="0"
    for ((i=1; i<=max; i++)); do
        options+=", $i"
    done
    echo "$options"
}

# Validate arguments and check for duplicates if ALLOW_DUPLICATES is "false"
function validate_arguments {
    local max_option="$1"
    shift
    declare -A seen_options

    for arg in "$@"; do
        # Check if within the valid range
        if ! [[ "$arg" =~ ^[0-9]+$ ]] || [ "$arg" -lt 1 ] || [ "$arg" -gt "$max_option" ]; then
            error_exit "Invalid option detected: $arg. Valid options are: $(generate_valid_options "$max_option")"
        fi

        # Check for duplicates if ALLOW_DUPLICATES is "false"
        if [[ "$ALLOW_DUPLICATES" == "false" ]]; then
            if [[ -n "${seen_options[$arg]:-}" ]]; then
                error_exit "Duplicate option detected: $arg. Please remove duplicate entries."
            else
                seen_options["$arg"]=1
            fi
        fi
    done
}

# Get the max number of options dynamically
max_option=$(( $(show_menu | wc -l) - 2 ))

if [ "$#" -gt 0 ]; then
    validate_arguments "$max_option" "$@"
    for arg in "$@"; do
        execute_choice "$arg"
    done
else
    while true; do
        show_menu
        read -p "Enter choice(s) [0-$max_option], separated by space or comma: " input
        echo ""

        IFS=' ,'
        read -ra choices <<< "$input"
        
        declare -A seen_options
        valid_input="true"

        for choice in "${choices[@]}"; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || { [ "$choice" -gt "$max_option" ] && [ "$choice" -ne 0 ]; }; then
                echo "Invalid option detected: $choice"
                echo "Valid options are: $(generate_valid_options "$max_option")"
                valid_input="false"
                break
            fi

            if [[ "$ALLOW_DUPLICATES" == "false" ]]; then
                if [[ -n "${seen_options[$choice]:-}" ]]; then
                    echo "Duplicate option detected: $choice. Please enter each option only once."
                    valid_input="false"
                    break
                else
                    seen_options["$choice"]=1
                fi
            fi
        done

        if [[ "$valid_input" == "true" ]]; then
            for choice in "${choices[@]}"; do
                execute_choice "$choice"
            done
        else
            echo "Please try again."
        fi
        echo ""
    done
fi