#!/bin/bash

# Example of using the image edit endpoint
# Note: This uses JSON format instead of multipart form data for simplicity
# The images should be base64-encoded PNG/JPEG data

echo "Testing gpt-image-1 edit endpoint..."

# You would need to provide actual base64-encoded images here
# For testing, you can use a small placeholder
curl -X POST https://openai-image-proxy.guitaripod.workers.dev/v1/images/edits \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dev-api-key" \
  -d '{
    "model": "gpt-image-1",
    "image": ["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="],
    "prompt": "Add a colorful sunset to the background",
    "n": 1,
    "size": "1024x1024",
    "quality": "high",
    "background": "auto",
    "input_fidelity": "low",
    "output_format": "png"
  }' | jq

echo -e "\n\nNote: To use this endpoint properly, you need to:"
echo "1. Convert your input image(s) to base64 format"
echo "2. Include up to 16 images in the 'image' array"
echo "3. Optionally include a mask image in base64 format"
echo "4. The gpt-image-1 model supports advanced features like input_fidelity"