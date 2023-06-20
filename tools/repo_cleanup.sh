#!/bin/bash
# Cleans unwanted files from the repo

SCRIPT_PATH=$(realpath "$0" | sed 's|\(.*\)/.*|\1|')
REPO_PATH=$(readlink -f "$SCRIPT_PATH/..")

echo [REPO_CLEANUP] Deleting ._ files...
find $REPO_PATH -name "._*" -type f -delete

echo [REPO_CLEANUP] Complete
