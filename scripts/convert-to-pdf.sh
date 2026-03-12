#!/bin/bash
# Convert workflow-docs markdown files to PDF
# Requires: npm (uses md-to-pdf via npx)

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKFLOW_DIR="$PROJECT_ROOT/artifacts/workflow-docs"
OUTPUT_DIR="$WORKFLOW_DIR/pdf"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find all markdown files in workflow-docs (exclude pdf subfolder)
MD_FILES=$(find "$WORKFLOW_DIR" -maxdepth 1 -name "*.md" -type f)

if [ -z "$MD_FILES" ]; then
    echo -e "\e[33mNo markdown files found in $WORKFLOW_DIR\e[0m"
    exit 0
fi

echo -e "\e[36m=== Markdown to PDF Converter ===\e[0m"
echo ""

# Process each markdown file
while IFS= read -r FILE; do
    FILENAME=$(basename "$FILE")
    PDF_NAME="${FILENAME%.md}.pdf"
    GENERATED_PDF="${FILE%.md}.pdf"
    FINAL_PDF="$OUTPUT_DIR/$PDF_NAME"

    echo -e "\e[32mConverting: $FILENAME -> pdf/$PDF_NAME\e[0m"
    
    # md-to-pdf generates PDF next to the source file
    npx --yes md-to-pdf "$FILE" 2>&1 > /dev/null

    if [ -f "$GENERATED_PDF" ]; then
        # Move PDF to the pdf/ subdirectory
        mv "$GENERATED_PDF" "$FINAL_PDF"
        echo -e "\e[32m  Done: $FINAL_PDF\e[0m"
    else
        echo -e "\e[31m  Failed to convert $FILENAME\e[0m"
    fi
done <<< "$MD_FILES"

echo ""
echo -e "\e[36m=== Conversion Complete ===\e[0m"
echo "PDFs saved to: $OUTPUT_DIR"
