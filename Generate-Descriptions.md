Here is a robust PowerShell script that accomplishes exactly what you're looking for.

To achieve "instant" generation from images, this script leverages the **Google Gemini API** (specifically the `gemini-2.5-flash` model, which is incredibly fast, cost-effective, and excellent at multimodal image-to-text tasks).

### Prerequisites Before Running

1. **Get an API Key:** You will need a free or pay-as-you-go API key from Google AI Studio.
2. **Install PowerShell 7+ (Recommended):** While it can work on older versions, PowerShell 7 handles modern web requests and JSON much more reliably.

---
To keep your workflow organized and avoid duplicating your API key across every single product folder, we can change the script to look for `api_key.txt` right in the **current working directory** (where you are executing the script from, i.e., `./`), while still looking for images inside the specified `$TARGET_FOLDER`.

Here is the fully updated, cross-platform script reflecting this change:

### The Updated Script (`Generate-Descriptions.ps1`)

```powershell
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The folder path containing your product images")]
    [string]$TARGET_FOLDER,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the text file holding your API key")]
    [string]$KEY_FILE_NAME = "api_key.txt"
)

# 1. Resolve the API Key path from the current directory (./)
$CurrentDir = Get-Location
$KeyFilePath = [System.IO.Path]::Combine($CurrentDir, $KEY_FILE_NAME)

if (-not (Test-Path $KeyFilePath)) {
    Write-Host "Error: API key file not found at $KeyFilePath" -ForegroundColor Red
    Write-Host "Please place your '$KEY_FILE_NAME' file in the current working directory ($CurrentDir)." -ForegroundColor Yellow
    exit
}

# Read key and trim any accidental whitespaces/newlines
$API_KEY = (Get-Content -Path $KeyFilePath -Raw).Trim()

if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Write-Host "Error: The API key file at $KeyFilePath is empty." -ForegroundColor Red
    exit
}

# 2. Resolve the Target Folder containing the images
try {
    $ResolvedFolder = (Resolve-Path $TARGET_FOLDER).Path
} catch {
    Write-Host "Error: Cannot find target folder '$TARGET_FOLDER'" -ForegroundColor Red
    exit
}

$OUTPUT_FILE = [System.IO.Path]::Combine($ResolvedFolder, "marketplace_listings.txt")

# ==================================================================================
# SCRIPT LOGIC
# ==================================================================================
$Uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$API_KEY"

# Supported image extensions
$ImageExtensions = @('.jpg', '.jpeg', '.png', '.webp')
$Images = Get-ChildItem -Path $ResolvedFolder | Where-Object { $_.Extension.ToLower() -in $ImageExtensions }

if ($Images.Count -eq 0) {
    Write-Host "No valid images found in $ResolvedFolder" -ForegroundColor Yellow
    exit
}

Write-Host "API Key loaded from current directory." -ForegroundColor Green
Write-Host "Found $($Images.Count) images in '$TARGET_FOLDER'. Starting generation..." -ForegroundColor Cyan
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
        Write-Host "Success! Saved to target folder output file.`n" -ForegroundColor Green

    } catch {
        Write-Host "Error processing $($Image.Name): $_" -ForegroundColor Red
    }
    
    # Small pause to respect standard rate limits
    Start-Sleep -Seconds 1
}

Write-Host "Done! All descriptions have been saved to: $OUTPUT_FILE" -ForegroundColor Green

```

---

### How Your Workspace Looks Now

You keep your API key in your central script directory, and target whatever folder you want:

```text
📁 current_directory/ (./)
├── 📄 Generate-Descriptions.ps1
├── 📄 api_key.txt                   <-- Checked here
└── 📁 Scalextric C1020 Hockenhiem/   <-- Passed as argument
    ├── 📷 car_front.jpg
    └── 📷 track_set.png

```

### Running It

```powershell
./Generate-Descriptions.ps1 'Scalextric C1020 Hockenhiem'

```

The script will successfully pull the key from your current directory, sweep the Scalextric folder for images, and output the `marketplace_listings.txt` file cleanly inside the Scalextric folder.
