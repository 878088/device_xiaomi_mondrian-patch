#!/bin/bash

# Script to apply patches to their respective directories
# Usage: ./apply_patches.sh

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Starting patch application from $SCRIPT_DIR"

# Keep track of success and failures
SUCCESSFUL=0
FAILED=0

# Convert backslashes to forward slashes for proper handling in bash
declare -a PATCHES=(
    "bionic/0001-bluetooth-Introduce-Savitech-LHDC-Codec-1-5.patch"
    "frameworks/base/0001-bluetooth-Introduce-Savitech-LHDC-Codec-2-5.patch"
    "hardware/interfaces/0001-bluetooth-Introduce-Savitech-LHDC-Codec-3-5.patch"
    "packages/apps/Settings/0001-Settings-bluetooth-Fix-generateSummary-out-of-bounds.patch"
    "packages/apps/Settings/0002-bluetooth-Introduce-Savitech-LHDC-Codec-4-5.patch"
    "packages/modules/Bluetooth/0001-bluetooth-Introduce-Savitech-LHDC-Codec-5-5.patch"
    "packages/modules/common/0001-Update-allow_deps.txt-for-btservice.patch"
)

# Get the Android root directory
# Assuming this script is run from within the Android source tree
# or that ANDROID_ROOT is defined
if [ -z "$ANDROID_ROOT" ]; then
    # Try to detect Android root by going up directories looking for .repo
    CURRENT_DIR="$PWD"
    while [ "$CURRENT_DIR" != "/" ]; do
        if [ -d "$CURRENT_DIR/.repo" ]; then
            ANDROID_ROOT="$CURRENT_DIR"
            break
        fi
        CURRENT_DIR=$(dirname "$CURRENT_DIR")
    done
    
    # If still not found, use the current directory
    if [ -z "$ANDROID_ROOT" ]; then
        ANDROID_ROOT="$PWD"
        echo "Warning: Android root directory not found. Using current directory."
    else
        echo "Detected Android root at: $ANDROID_ROOT"
    fi
else
    echo "Using Android root from env: $ANDROID_ROOT"
fi

# Clone LHDC library repository
LHDC_REPO="https://github.com/flakeforever/android_external_liblhdc.git"
LHDC_TARGET_DIR="$ANDROID_ROOT/external/liblhdc"

echo "Cloning LHDC library repository..."
if [ -d "$LHDC_TARGET_DIR" ]; then
    echo "Directory $LHDC_TARGET_DIR already exists."
    echo "Updating repository..."
    git -C "$LHDC_TARGET_DIR" pull
    if [ $? -eq 0 ]; then
        echo "✅ Successfully updated LHDC library"
    else
        echo "❌ Failed to update LHDC library"
        FAILED=$((FAILED+1))
    fi
else
    # Ensure parent directory exists
    mkdir -p "$(dirname "$LHDC_TARGET_DIR")"
    
    # Clone the repository
    if git clone "$LHDC_REPO" "$LHDC_TARGET_DIR"; then
        echo "✅ Successfully cloned LHDC library to $LHDC_TARGET_DIR"
    else
        echo "❌ Failed to clone LHDC library"
        FAILED=$((FAILED+1))
    fi
fi
echo "------------------------------------"

# Process each patch
for patch_rel_path in "${PATCHES[@]}"; do
    # Get the full path to the patch
    patch_file="$SCRIPT_DIR/$patch_rel_path"
    
    echo "Processing patch: $patch_file"
    
    # Extract the subdirectory from the patch path
    subdir=$(dirname "$patch_rel_path")
    
    # Full path to target directory
    target_dir="$ANDROID_ROOT/$subdir"
    
    # Check if patch file exists
    if [ ! -f "$patch_file" ]; then
        echo "Error: Patch file $patch_file doesn't exist"
        FAILED=$((FAILED+1))
        continue
    fi
    
    # Check if directory exists
    if [ ! -d "$target_dir" ]; then
        echo "Error: Target directory $target_dir doesn't exist"
        FAILED=$((FAILED+1))
        continue
    fi
    
    # Apply the patch
    echo "Applying patch to $target_dir"
    if git -C "$target_dir" am "$patch_file"; then
        echo "✅ Successfully applied patch: $(basename "$patch_file")"
        SUCCESSFUL=$((SUCCESSFUL+1))
    else
        echo "❌ Failed to apply patch: $(basename "$patch_file")"
        # Abort any failed patch application
        git -C "$target_dir" am --abort
        FAILED=$((FAILED+1))
    fi
    
    echo "------------------------------------"
done

# Summary
echo "Patch application completed!"
echo "Successfully applied: $SUCCESSFUL"
echo "Failed to apply: $FAILED"

if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi