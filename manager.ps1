# Bouquet Gift Manager Engine
param (
    [string]$Action
)

$RepoDir = $PSScriptRoot
if (-not (Test-Path "$RepoDir\.git")) {
    if (Test-Path "C:\Users\corte\Desktop\temp\New folder\.git") {
        $RepoDir = "C:\Users\corte\Desktop\temp\New folder"
    } elseif (Test-Path "C:\Users\corte\Desktop\New folder\.git") {
        $RepoDir = "C:\Users\corte\Desktop\New folder"
    }
}
Set-Location $RepoDir

function Show-Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Magenta
    Write-Host "         VIRTUAL BOUQUET GIFT MANAGER & DEPLOYER          " -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Magenta
    $currentBranch = (git branch --show-current 2>$null)
    Write-Host " Repo Directory : $RepoDir" -ForegroundColor DarkGray
    Write-Host " Active Branch  : $currentBranch" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Update-NameInHtml([string]$NewName) {
    if ([string]::IsNullOrWhiteSpace($NewName)) { return }
    $htmlFile = Join-Path $RepoDir "marya.html"
    if (-not (Test-Path $htmlFile)) {
        Write-Host "Error: marya.html not found!" -ForegroundColor Red
        return
    }

    $raw = Get-Content -Path $htmlFile -Raw -Encoding UTF8
    $raw = [regex]::Replace($raw, 'content="A special virtual bouquet gift for [^"]+"', "content=`"A special virtual bouquet gift for $NewName`"")
    $raw = [regex]::Replace($raw, '<title>A Special Bouquet For [^<]+</title>', "<title>A Special Bouquet For $NewName</title>")
    $raw = [regex]::Replace($raw, '<h1 id="titleDisplay">To My Dearest [^<]+</h1>', "<h1 id=`"titleDisplay`">To My Dearest $NewName</h1>")
    $raw = [regex]::Replace($raw, '<p>My [^,<]+,</p>', "<p>My $NewName,</p>")
    $raw = [regex]::Replace($raw, 'alt="A memory with [^"]+"', "alt=`"A memory with $NewName`"")
    $raw = [regex]::Replace($raw, 'And if you ever need me, [^,]+, please remember', "And if you ever need me, $NewName, please remember")
    $raw = [regex]::Replace($raw, 'still looking for my [^.<&#]+', "still looking for my $NewName")

    $raw | Set-Content -Path $htmlFile -Encoding UTF8
    Write-Host "[OK] Updated recipient name to '$NewName' in marya.html" -ForegroundColor Green
}

function Update-RenderYaml([string]$BranchName) {
    $yamlFile = Join-Path $RepoDir "render.yaml"
    if (Test-Path $yamlFile) {
        $raw = Get-Content -Path $yamlFile -Raw -Encoding UTF8
        $raw = [regex]::Replace($raw, '(?m)^\s*branch:\s*.+$', "    branch: $BranchName")
        $raw | Set-Content -Path $yamlFile -Encoding UTF8
        Write-Host "[OK] Updated branch to '$BranchName' in render.yaml" -ForegroundColor Green
    }
}

function Ensure-Dockerfile {
    $dockerFile = Join-Path $RepoDir "Dockerfile"
    $dockerContent = @"
FROM nginx:alpine

COPY . /usr/share/nginx/html/
COPY marya.html /usr/share/nginx/html/index.html

EXPOSE 80
"@
    $dockerContent | Set-Content -Path $dockerFile -Encoding UTF8

    $dockerIgnore = Join-Path $RepoDir ".dockerignore"
    if (-not (Test-Path $dockerIgnore)) {
        @"
.git
.gitignore
__pycache__
*.py
*.yaml
*.yml
*.md
Dockerfile
.dockerignore
*.bat
*.ps1
graphify/
graphify-out/
tools/
"@ | Set-Content -Path $dockerIgnore -Encoding UTF8
    }
    Write-Host "[OK] Verified Dockerfile & .dockerignore (safe for any photos)" -ForegroundColor Green
}

function Import-PicturesFromPath([string]$SourcePath, [string]$RecipientName) {
    if ([string]::IsNullOrWhiteSpace($SourcePath)) { return }
    $SourcePath = $SourcePath.Trim('"').Trim("'").Trim()
    
    $desktopDir = [Environment]::GetFolderPath("Desktop")
    $resolvedPath = $SourcePath
    if (-not (Test-Path $resolvedPath)) {
        $candidate = Join-Path $desktopDir $SourcePath
        if (Test-Path $candidate) {
            $resolvedPath = $candidate
        }
    }

    if (-not (Test-Path $resolvedPath)) {
        Write-Host "Error: Path '$SourcePath' does not exist!" -ForegroundColor Red
        return
    }

    $imageFiles = @()
    if ((Get-Item $resolvedPath) -is [System.IO.DirectoryInfo]) {
        $imageFiles = Get-ChildItem -Path $resolvedPath -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|webp|gif)$' }
    } else {
        $imageFiles = @(Get-Item $resolvedPath)
    }

    if ($imageFiles.Count -eq 0) {
        Write-Host "No images found in $resolvedPath" -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($imageFiles.Count) image(s) in $resolvedPath" -ForegroundColor Cyan

    Get-ChildItem -Path $RepoDir -File | Where-Object { $_.Name -match '^[0-9]+\.(jpg|jpeg|png|webp|gif)$' } | Remove-Item -Force

    $copiedNames = @()
    $idx = 1
    foreach ($img in $imageFiles) {
        $ext = $img.Extension.ToLower()
        if ($ext -eq ".jpeg") { $ext = ".jpg" }
        $destName = "$idx$ext"
        $destPath = Join-Path $RepoDir $destName
        Copy-Item -Path $img.FullName -Destination $destPath -Force
        $copiedNames += $destName
        Write-Host "  -> Copied: $($img.Name) as $destName" -ForegroundColor DarkGray
        $idx++
    }

    Update-HtmlPolaroids -ImageNames $copiedNames -RecipientName $RecipientName
    Ensure-Dockerfile
}

function Update-HtmlPolaroids([string[]]$ImageNames, [string]$RecipientName) {
    $htmlFile = Join-Path $RepoDir "marya.html"
    if (-not (Test-Path $htmlFile)) { return }

    if ([string]::IsNullOrWhiteSpace($RecipientName)) {
        $RecipientName = "Cassy"
    }

    $raw = Get-Content -Path $htmlFile -Raw -Encoding UTF8
    $raw = [regex]::Replace($raw, '(?s)\s*<div class="polaroid">.*?</div>\r?\n?', '')

    if ($ImageNames.Count -gt 0) {
        $hooks = @(
            'warmth.</p>',
            'melody.</p>',
            'Find me.</p>',
            'find me.</p>',
            'enough.</p>'
        )

        for ($i = 0; $i -lt $ImageNames.Count; $i++) {
            $imgName = $ImageNames[$i]
            $polaroidHtml = "`r`n`r`n<div class=`"polaroid`"><img src=`"$imgName`" alt=`"A memory with $RecipientName`"></div>`r`n"
            
            $hookIndex = $i % $hooks.Count
            $hookText = $hooks[$hookIndex]
            
            if ($raw.Contains($hookText)) {
                $raw = $raw.Replace($hookText, "$hookText$polaroidHtml")
            } else {
                $editMarker = '<div class="edit-controls">'
                $raw = $raw.Replace($editMarker, "$polaroidHtml$editMarker")
            }
        }
    }

    $raw | Set-Content -Path $htmlFile -Encoding UTF8
    Write-Host "[OK] Injected $($ImageNames.Count) polaroid photo(s) into letter" -ForegroundColor Green
}

function Create-NewBranch {
    Show-Header
    Write-Host "--- CREATE NEW BRANCH ---" -ForegroundColor Yellow
    $bName = Read-Host "Enter new branch name (e.g. cassy)"
    $bName = $bName.Trim()
    if ([string]::IsNullOrWhiteSpace($bName)) {
        Write-Host "Branch name cannot be empty." -ForegroundColor Red
        return
    }

    git checkout -b $bName
    Update-RenderYaml $bName
    Ensure-Dockerfile
    
    $push = Read-Host "Do you want to push this branch to GitHub now? (Y/N)"
    if ($push -match '^[Yy]') {
        git add .
        git commit -m "Initialize branch $bName"
        git push -u origin $bName
    }
}

function Delete-Branch {
    Show-Header
    Write-Host "--- DELETE A BRANCH ---" -ForegroundColor Yellow
    Write-Host "Available local branches:" -ForegroundColor Cyan
    git branch
    Write-Host ""
    $bName = Read-Host "Enter branch name to delete"
    $bName = $bName.Trim()
    if ([string]::IsNullOrWhiteSpace($bName)) { return }

    $currentBranch = (git branch --show-current).Trim()
    if ($bName -eq $currentBranch) {
        Write-Host "Cannot delete the active branch! Switching to 'main' or 'cassy' first..." -ForegroundColor Yellow
        git checkout cassy 2>$null
        if ($LASTEXITCODE -ne 0) { git checkout main 2>$null }
    }

    git branch -D $bName
    $rem = Read-Host "Do you also want to delete branch '$bName' on GitHub remote? (Y/N)"
    if ($rem -match '^[Yy]') {
        git push origin --delete $bName
    }
}

function Switch-Branch {
    Show-Header
    Write-Host "--- SWITCH BRANCH ---" -ForegroundColor Yellow
    git branch -a
    Write-Host ""
    $bName = Read-Host "Enter branch name to switch to"
    $bName = $bName.Trim()
    if (-not [string]::IsNullOrWhiteSpace($bName)) {
        git checkout $bName
    }
}

function Quick-Setup {
    Show-Header
    Write-Host "--- QUICK CUSTOMIZE: NEW RECIPIENT ---" -ForegroundColor Yellow
    Write-Host "This wizard configures a new branch, recipient name, and pictures in one go!" -ForegroundColor DarkGray
    Write-Host ""

    $name = Read-Host "1. Enter Recipient Name (e.g. Cassy)"
    $name = $name.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Host "Name cannot be empty!" -ForegroundColor Red
        return
    }

    $defaultBranch = $name.ToLower() -replace '\s+', '-'
    $branchPrompt = Read-Host "2. Enter Branch Name [Press Enter for '$defaultBranch']"
    $branchName = if ([string]::IsNullOrWhiteSpace($branchPrompt)) { $defaultBranch } else { $branchPrompt.Trim() }

    git checkout -B $branchName
    Write-Host "[OK] Checked out branch '$branchName'" -ForegroundColor Green

    Update-NameInHtml $name
    Update-RenderYaml $branchName
    Ensure-Dockerfile

    Write-Host ""
    Write-Host "3. Pictures Setup:" -ForegroundColor Cyan
    Write-Host "   - Enter a Desktop folder path (e.g. cassy_photos or C:\Users\corte\Desktop\cassy_pics)"
    Write-Host "   - Or drag & drop a folder/files here"
    Write-Host "   - Or press Enter to keep current photos / skip"
    $photoPath = Read-Host "Photo path"
    if (-not [string]::IsNullOrWhiteSpace($photoPath)) {
        Import-PicturesFromPath -SourcePath $photoPath -RecipientName $name
    }

    Write-Host ""
    $doPush = Read-Host "Commit and push to GitHub now? (Y/N)"
    if ($doPush -match '^[Yy]') {
        git add .
        git commit -m "Customize bouquet gift for $name"
        git push -u origin $branchName
        Write-Host ""
        Write-Host "SUCCESS! Pushed to GitHub on branch '$branchName'!" -ForegroundColor Green
        Write-Host "If connected to Render, it will automatically deploy." -ForegroundColor Cyan
    }
}

function Custom-PicturesOnly {
    Show-Header
    Write-Host "--- IMPORT PICTURES FROM DESKTOP PATH ---" -ForegroundColor Yellow
    $currentName = "Cassy"
    $htmlFile = Join-Path $RepoDir "marya.html"
    if (Test-Path $htmlFile) {
        $match = Select-String -Path $htmlFile -Pattern '<h1 id="titleDisplay">To My Dearest ([^<]+)</h1>'
        if ($match.Matches.Groups.Count -gt 1) {
            $currentName = $match.Matches.Groups[1].Value
        }
    }

    Write-Host "Current Recipient detected: $currentName" -ForegroundColor Cyan
    Write-Host "Enter Desktop folder name (e.g. photos), full path, or drag and drop folder here:"
    $p = Read-Host "Source Path"
    if (-not [string]::IsNullOrWhiteSpace($p)) {
        Import-PicturesFromPath -SourcePath $p -RecipientName $currentName
        $commit = Read-Host "Commit and push new pictures to GitHub? (Y/N)"
        if ($commit -match '^[Yy]') {
            $b = (git branch --show-current).Trim()
            git add .
            git commit -m "Update pictures for $currentName"
            git push origin $b
        }
    }
}

function Custom-NameOnly {
    Show-Header
    Write-Host "--- CHANGE RECIPIENT NAME ---" -ForegroundColor Yellow
    $newName = Read-Host "Enter new recipient name (e.g. Cassy)"
    if (-not [string]::IsNullOrWhiteSpace($newName)) {
        Update-NameInHtml $newName.Trim()
        $commit = Read-Host "Commit and push name change to GitHub? (Y/N)"
        if ($commit -match '^[Yy]') {
            $b = (git branch --show-current).Trim()
            git add marya.html
            git commit -m "Update recipient name to $newName"
            git push origin $b
        }
    }
}

function Test-Locally {
    Show-Header
    Write-Host "Starting local test server on http://localhost:8000..." -ForegroundColor Cyan
    Start-Process "http://localhost:8000"
    python serve.py
}

while ($true) {
    Show-Header
    Write-Host "  [1] Quick Setup (New Person: Branch + Name + Photos + Push)" -ForegroundColor Green
    Write-Host "  [2] Create a New Branch" -ForegroundColor White
    Write-Host "  [3] Delete a Branch (Local and/or Remote)" -ForegroundColor White
    Write-Host "  [4] Switch / Checkout Branch" -ForegroundColor White
    Write-Host "  [5] Change Recipient Name in Letter" -ForegroundColor White
    Write-Host "  [6] Import Pictures from Desktop Path" -ForegroundColor White
    Write-Host "  [7] Commit & Push Current Branch to GitHub" -ForegroundColor White
    Write-Host "  [8] Preview / Test Locally in Browser" -ForegroundColor White
    Write-Host "  [0] Exit" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Select an option [0-8]"

    switch ($choice) {
        "1" { Quick-Setup; Pause }
        "2" { Create-NewBranch; Pause }
        "3" { Delete-Branch; Pause }
        "4" { Switch-Branch; Pause }
        "5" { Custom-NameOnly; Pause }
        "6" { Custom-PicturesOnly; Pause }
        "7" {
            $b = (git branch --show-current).Trim()
            git add .
            $msg = Read-Host "Commit message [Enter for default]"
            if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Update bouquet gift" }
            git commit -m $msg
            git push -u origin $b
            Pause
        }
        "8" { Test-Locally }
        "0" { break }
        default { Write-Host "Invalid choice, please try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
