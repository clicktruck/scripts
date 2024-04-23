#!/bin/bash

# This script will iterate over all sub-directories one level deep in the current directory
# and execute 'terraform fmt' inside each.

target_dir=$1
cd $target_dir

# Get the current directory
current_dir=$(pwd)

# Loop through each item in the current directory
for item in "$current_dir"/*; do
    # Check if the item is a directory
    if [ -d "$item" ]; then
        echo "Running terraform fmt in $item"
        # Change to the directory
        cd "$item"
        # Run terraform fmt
        terraform fmt
        # Return to the original directory
        cd "$current_dir"
    fi
done

echo "Completed running terraform fmt in all sub-directories."
