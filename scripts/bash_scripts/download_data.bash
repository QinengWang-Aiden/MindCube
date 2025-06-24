#!/bin/bash

# Set variables
REPO="Inevitablevalor/MindCube"
ZIP_NAME="data.zip"

echo "Downloading MindCube dataset from Hugging Face..."

# Method 1: Try huggingface-cli (recommended for private repos)
if command -v huggingface-cli &> /dev/null; then
    echo "Attempting download with huggingface-cli..."
    huggingface-cli download $REPO data.zip --local-dir ./temp_download --repo-type dataset 2>/dev/null
    
    if [ -f "./temp_download/data.zip" ]; then
        mv "./temp_download/data.zip" "$ZIP_NAME"
        rm -rf ./temp_download
        echo "✓ Download successful via huggingface-cli"
    else
        echo "ℹ huggingface-cli download failed (may need authentication)"
        rm -rf ./temp_download 2>/dev/null
    fi
else
    echo "ℹ huggingface-cli not found. Installing..."
    pip install -q huggingface-hub
    echo "Please run the script again after installation."
    exit 1
fi

# Method 2: Try direct download if Method 1 failed
if [ ! -f "$ZIP_NAME" ]; then
    echo "Attempting direct download..."
    
    URL="https://huggingface.co/datasets/$REPO/resolve/main/data.zip"
    curl -L "$URL" -o "$ZIP_NAME" -s
    
    # Check if we got a real zip file
    if [ -f "$ZIP_NAME" ] && file "$ZIP_NAME" | grep -q "Zip archive"; then
        echo "✓ Download successful via direct URL"
    else
        echo "✗ Direct download failed or got error response"
        if [ -f "$ZIP_NAME" ]; then
            echo "Error response:"
            head -3 "$ZIP_NAME" 2>/dev/null
            rm "$ZIP_NAME"
        fi
    fi
fi

# Extract if successful
if [ -f "$ZIP_NAME" ] && file "$ZIP_NAME" | grep -q "Zip archive"; then
    echo "Extracting dataset..."
    
    # Create temporary directory for extraction
    mkdir -p temp_extract
    unzip -q "$ZIP_NAME" -d temp_extract
    
    if [ $? -eq 0 ]; then
        echo "✓ Extraction complete"
        rm "$ZIP_NAME"
        
        # Move contents from nested data directory to workspace root
        if [ -d "temp_extract/data" ]; then
            # Remove existing data directory if it exists
            rm -rf data
            # Move the inner data directory to workspace root
            mv temp_extract/data .
            echo "✓ Dataset moved to ./data directory"
        else
            # If no nested data directory, move everything
            mkdir -p data
            mv temp_extract/* data/ 2>/dev/null
            echo "✓ Dataset contents moved to ./data directory"
        fi
        
        # Clean up
        rm -rf temp_extract
        rm -rf ./data/__MACOSX 2>/dev/null
        rm -f ./data/.DS_Store 2>/dev/null
        
        echo "🎉 Dataset successfully downloaded!"
        echo "Dataset structure:"
        ls -la ./data/
    else
        echo "✗ Extraction failed"
        rm -rf temp_extract
    fi
else
    echo ""
    echo "❌ Download failed. This could be because:"
    echo "1. The dataset is private and requires authentication"
    echo "2. Network connectivity issues"
    echo "3. The dataset repository name has changed"
    echo ""
    echo "💡 Solutions:"
    echo "• If dataset is private, authenticate first: huggingface-cli login"
    echo "• Check your internet connection"
    echo "• Verify the repository exists: https://huggingface.co/datasets/$REPO"
    echo ""
fi
