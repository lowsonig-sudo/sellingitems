[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The folder path containing your product images and API key file")]
    [string]$TARGET_FOLDER,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the text file holding your API key")]
    [string]$KEY_FILE_NAME = "api_key.txt"
)

# Resolve the path to ensure it's absolute
$ResolvedFolder = Resolve-Path $TARGET_FOLDER
$KeyFilePath = Join-Path $ResolvedFolder $KEY_FILE_NAME
$OUTPUT_FILE = Join-Path $ResolvedFolder "marketplace_listings.txt"

# 1. Check if the API key file exists and read it
if (-not (Test-Path $KeyFilePath)) {
    Write-Host "Error: API key file not found at $KeyFilePath" -ForegroundColor Red
    Write-Host "Please create a '$KEY_FILE_NAME' file inside the folder containing only your Gemini API key." -ForegroundColor Yellow
    exit
}

# Read key and trim any accidental whitespaces/newlines
$API_KEY = (Get-Content -Path $KeyFilePath -Raw).Trim()

if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Write-Host "Error: The API key file at $KeyFilePath is empty." -ForegroundColor Red
    exit
}

# ==================================================================================
# SCRIPT LOGIC
# ==================================================================================
$Uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$API_KEY"

# Supported image extensions (excluding the output text file and key file)
$ImageExtensions = @('.jpg', '.jpeg', '.png', '.webp')
$Images = Get-ChildItem -Path $ResolvedFolder | Where-Object { $_.Extension.ToLower() -in $ImageExtensions }

if ($Images.Count -eq 0) {
    Write-Host "No valid images found in $ResolvedFolder" -ForegroundColor Yellow
    exit
}

Write-Host "API Key loaded successfully." -ForegroundColor Green
Write-Host "Found $($Images.Count) images. Starting description generation..." -ForegroundColor Cyan
"--- MARKETPLACE GENERATED LISTINGS ---`n" | Out-File -FilePath $OUTPUT_FILE -Encoding utf8

foreach ($Image in $Images) {
    Write-Host "Processing: $($Image.Name)..." -ForegroundColor Cyan

    # Convert image to Base64
    try {
        $Bytes = [System.IO.File]::ReadAllBytes($Image.FullName)
        $Base64Image = [Convert]::ToBase64String($Bytes)
    } catch {
        Write-Host "Failed to read image file $($Image.Name): $_" -ForegroundColor Red
        continue
    }
    
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
