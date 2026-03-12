#!/bin/bash
# Cleanup script: removes all generated artifacts and build output
# Removes: artifacts/ (screenshots, execution-prompt, workflow-docs) and target/

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DIRS_TO_CLEAN=(
    "artifacts:Generated artifacts"
    "target:Build artifacts"
)

# Parse command-line arguments
FORCE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-f|--force]"
            exit 1
            ;;
    esac
done

echo -e "\e[36m=== Workflow Cleanup ===\e[0m"
echo ""

# Collect what will be deleted
TO_DELETE=()

for entry in "${DIRS_TO_CLEAN[@]}"; do
    DIR_PATH="${entry%%:*}"
    DIR_NAME="${entry##*:}"
    FULL_PATH="$PROJECT_ROOT/$DIR_PATH"

    if [ -d "$FULL_PATH" ]; then
        FILE_COUNT=$(find "$FULL_PATH" -type f | wc -l | tr -d ' ')
        PADDED_NAME=$(printf "%-20s" "$DIR_NAME")
        TO_DELETE+=("  $PADDED_NAME $DIR_PATH/  ($FILE_COUNT file(s))")
    fi
done

if [ ${#TO_DELETE[@]} -eq 0 ]; then
    echo -e "\e[32mNothing to clean up. All directories are already removed.\e[0m"
    exit 0
fi

echo -e "\e[33mThe following directories will be deleted:\e[0m"
for item in "${TO_DELETE[@]}"; do
    echo -e "\e[33m$item\e[0m"
done
echo ""

# Confirm unless --force
if [ $FORCE -eq 0 ]; then
    read -p "Proceed with cleanup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\e[31mCleanup cancelled.\e[0m"
        exit 0
    fi
fi

echo ""

# Delete each directory entirely
for entry in "${DIRS_TO_CLEAN[@]}"; do
    DIR_PATH="${entry%%:*}"
    FULL_PATH="$PROJECT_ROOT/$DIR_PATH"

    if [ -d "$FULL_PATH" ]; then
        rm -rf "$FULL_PATH"
        echo -e "\e[32m  Removed: $DIR_PATH/\e[0m"
    fi
done

echo ""
echo -e "\e[36m=== Cleanup Complete ===\e[0m"