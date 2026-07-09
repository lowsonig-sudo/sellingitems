# ==================================================================================
# CONFIGURATION
# ==================================================================================
$API_KEY = "YOUR_GEMINI_API_KEY_HERE"
$TARGET_FOLDER = "C:\Path\To\Your\Product\Images"
$OUTPUT_FILE = Join-Path $TARGET_FOLDER "marketplace_listings.txt"

# ==================================================================================
# SCRIPT LOGIC
# ==================================================================================
$Uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$API_KEY"

# Supported image extensions
$ImageExtensions = @('.jpg', '.jpeg', '.png', '.webp')
$Images = Get-ChildItem -Path $TARGET_FOLDER | Where-Object { $_.Extension.ToLower() -in $ImageExtensions }

if ($Images.Count -eq 0) {
    Write-Host "No valid images found in $TARGET_FOLDER" -ForegroundColor Yellow
    exit
}

Write-Host "Found $($Images.Count) images. Starting description generation..." -ForegroundColor Cyan
"--- MARKETPLACE GENERATED LISTINGS ---`n" | Out-File -FilePath $OUTPUT_FILE -Encoding utf8

foreach ($Image in $Images) {
    Write-Host "Processing: $($Image.Name)..." -ForegroundColor Data

    # Convert image to Base64
    $Bytes = [System.IO.File]::ReadAllBytes($Image.FullName)
    $Base64Image = [Convert]::ToBase64String($Bytes)
    
    # Determine MIME type
    $MimeType = switch ($Image.Extension.ToLower()) {
        ".jpg"  { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".png"  { "image/png" }
        ".webp" { "image/webp" }
    }

    # Define the prompt for the AI
    $PromptText = "You are an expert e-commerce copywriter. Analyze this product image and provide: " +
                  "1. A catchy, SEO-optimized marketplace Title (max 80 characters). " +
                  "2. A compelling Description highlighting key features, potential condition (based on visual cues), and target audience. " +
                  "3. 5-8 relevant tags/keywords. Keep the formatting clean using Markdown."

    # Construct the JSON Payload
    $Payload = @{
        contents = @(
            @{
                parts = @(
                    @{ text = $PromptText },
                    @{
                        inlineData = @{
                            mimeType = $MimeType
                            data     = $Base64Image
                        }
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        # Send request to Gemini API
        $Response = Invoke-RestMethod -Uri $Uri -Method Post -Body $Payload -ContentType "application/json"
        
        # Extract the text from the response structure
        $GeneratedText = $Response.candidates[0].content.parts[0].text

        # Format the output for the text file
        $OutputBlock = @"
==================================================================================
FILE: $($Image.Name)
==================================================================================
$GeneratedText

"@
        # Append to the output file and print to console
        $OutputBlock | Out-File -FilePath $OUTPUT_FILE -Append -Encoding utf8
        Write-Host "Success! Saved to output file.`n" -ForegroundColor Green

    } catch {
        Write-Host "Error processing $($Image.Name): $_" -ForegroundColor Red
    }
    
    # Small pause to respect standard rate limits
    Start-Sleep -Seconds 1
}

Write-Host "Done! All descriptions have been saved to: $OUTPUT_FILE" -ForegroundColor Green
