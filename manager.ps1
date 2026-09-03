# Bouquet Gift Manager Engine with Custom Letter Editor
param ([string]$Action)

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
    $curName = Get-CurrentRecipientName
    Write-Host " Active Branch  : $currentBranch" -ForegroundColor Yellow
    Write-Host " Recipient Name : $curName" -ForegroundColor Green
    Write-Host " Repo Directory : $RepoDir" -ForegroundColor DarkGray
    Write-Host "==========================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Get-CurrentRecipientName {
    $htmlFile = Join-Path $RepoDir "marya.html"
    if (Test-Path $htmlFile) {
        $pattern = '<h1 id="titleDisplay">To My Dearest ([^<]+)</h1>'
        $match = Select-String -Path $htmlFile -Pattern $pattern
        if ($match -and $match.Matches.Groups.Count -gt 1) {
            return $match.Matches.Groups[1].Value.Trim()
        }
    }
    return "Cassy"
}

function Get-CurrentImages {
    $imgs = @(Get-ChildItem -Path $RepoDir -File | Where-Object { $_.Name -match '^[0-9]+\.(jpg|jpeg|png|webp|gif)$' } | Sort-Object { [int]($_.BaseName) } | Select-Object -ExpandProperty Name)
    return $imgs
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

function Set-LetterInHtml([string[]]$Paragraphs, [string]$RecipientName) {
    if ([string]::IsNullOrWhiteSpace($RecipientName)) {
        $RecipientName = Get-CurrentRecipientName
    }

    $htmlFile = Join-Path $RepoDir "marya.html"
    if (-not (Test-Path $htmlFile)) { return }

    $cleanParas = @()
    foreach ($p in $Paragraphs) {
        $trimmed = $p.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $trimmed = $trimmed -replace '\[NAME\]', $RecipientName
            $cleanParas += $trimmed
        }
    }

    if ($cleanParas.Count -eq 0) { return }

    $images = Get-CurrentImages
    $imgCount = $images.Count
    $paraCount = $cleanParas.Count

    $insertMap = @{}
    if ($imgCount -gt 0) {
        for ($i = 0; $i -lt $imgCount; $i++) {
            $slot = [Math]::Min($paraCount - 1, [Math]::Max(1, [int][Math]::Round(($i + 1) * ($paraCount / ($imgCount + 1)))))
            if (-not $insertMap.ContainsKey($slot)) {
                $insertMap[$slot] = @()
            }
            $insertMap[$slot] += $images[$i]
        }
    }

    $letterSb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $paraCount; $i++) {
        [void]$letterSb.Append("<p>$($cleanParas[$i])</p>`r`n`r`n")
        if ($insertMap.ContainsKey($i + 1)) {
            foreach ($img in $insertMap[$i + 1]) {
                [void]$letterSb.Append("<div class=`"polaroid`"><img src=`"$img`" alt=`"A memory with $RecipientName`"></div>`r`n`r`n")
            }
        }
    }

    $newLetterContent = $letterSb.ToString().TrimEnd()
    $raw = Get-Content -Path $htmlFile -Raw -Encoding UTF8
    
    $raw = [regex]::Replace($raw, 'content="A special virtual bouquet gift for [^"]+"', "content=`"A special virtual bouquet gift for $RecipientName`"")
    $raw = [regex]::Replace($raw, '<title>A Special Bouquet For [^<]+</title>', "<title>A Special Bouquet For $RecipientName</title>")
    $raw = [regex]::Replace($raw, '<h1 id="titleDisplay">To My Dearest [^<]+</h1>', "<h1 id=`"titleDisplay`">To My Dearest $RecipientName</h1>")

    $pattern = '(?s)<div class="letter-text" id="loveLetterText">.*?</div>\s*<div class="edit-controls">'
    $replacement = "<div class=`"letter-text`" id=`"loveLetterText`">$newLetterContent</div>`r`n                <div class=`"edit-controls`">"
    $raw = [regex]::Replace($raw, $pattern, $replacement)

    $raw | Set-Content -Path $htmlFile -Encoding UTF8
    Write-Host "[OK] New letter successfully written into marya.html!" -ForegroundColor Green
    if ($imgCount -gt 0) {
        Write-Host "[OK] Balanced $imgCount photo(s) into the letter." -ForegroundColor Cyan
    }
}

function Get-Preset-Romantic([string]$Name) {
    return @(
        "My Dearest $Name,",
        "I wanted to give you these flowers as a little reminder of how much you mean to me. Even though they bloom on a screen, every petal holds a piece of my heart and all my genuine love for you.",
        "Thank you for bringing so much light, comfort, and laughter into my life. Being around you makes everything easier, warmer, and so much more meaningful.",
        "Whenever your days feel heavy or busy, I hope you look at this bouquet and remember that you have someone who always believes in you, cheers for you, and loves you deeply.",
        "No matter where life leads us, please know that you never have to face anything alone. I will always be right here in your corner.",
        "Thank you for simply being you, $Name. You make my world a thousand times brighter just by being in it."
    )
}

function Get-Preset-Appreciation([string]$Name) {
    return @(
        "To My Wonderful $Name,",
        "These virtual flowers are a small token to say thank you for everything you are and everything you do.",
        "Your kindness, your warmth, and your smile have a way of brightening even the gloomiest days. Having you in my life is a gift I never take for granted.",
        "Life can get busy and unpredictable, but I want to take a moment today to remind you that your presence makes an unforgettable difference.",
        "I hope this little surprise brings a genuine smile to your face, just like you always bring to mine."
    )
}

function Get-Preset-Celebration([string]$Name) {
    return @(
        "Happy Special Day, $Name!",
        "Today is all about celebrating you - the radiant, wonderful, and extraordinary person that you are.",
        "I picked every virtual flower in this bouquet to wish you endless happiness, good health, and success in everything your heart desires.",
        "May this year bring you closer to all your dreams, surround you with deep peace, and give you countless beautiful memories to smile about.",
        "Here is to celebrating you today and always, $Name!"
    )
}

function Get-Preset-Nostalgic([string]$Name) {
    return @(
        "My $Name,",
        "I am sorry if it has been a while since we talked like this. I know life has taken us in different directions, and maybe things between us aren't what they used to be. But some feelings don't disappear just because we stop talking about them.",
        "I wanted to give you these virtual flowers. I hope when you see them, you don't just see a picture, but a little reminder that someone still remembers you with warmth.",
        "Some people come into our lives like songs. Even when the music stops, somehow, you still remember the melody.",
        "And if you ever need me, $Name, please remember that I am only one call away. I won't ask for anything, and I won't expect anything. I will simply be there.",
        "So if you ever find yourself somewhere in another lifetime, and you feel like you have known me before...",
        "Maybe that is just me, still looking for my $Name."
    )
}

function Edit-LetterInNotepad {
    Show-Header
    Write-Host "--- EDIT LETTER IN NOTEPAD ---" -ForegroundColor Yellow
    $curName = Get-CurrentRecipientName
    $txtPath = Join-Path $RepoDir "letter.txt"

    if (-not (Test-Path $txtPath)) {
        $htmlFile = Join-Path $RepoDir "marya.html"
        $raw = Get-Content -Path $htmlFile -Raw -Encoding UTF8
        $pattern = '(?s)<div class="letter-text" id="loveLetterText">(.*?)</div>\s*<div class="edit-controls">'
        $match = [regex]::Match($raw, $pattern)
        if ($match.Success) {
            $inner = $match.Groups[1].Value
            $inner = [regex]::Replace($inner, '(?s)<div class="polaroid">.*?</div>', '')
            $paras = [regex]::Matches($inner, '(?s)<p>(.*?)</p>') | ForEach-Object { $_.Groups[1].Value.Trim() }
            $innerTxt = ($paras -join "`r`n`r`n")
            $innerTxt | Set-Content -Path $txtPath -Encoding UTF8
        } else {
            (Get-Preset-Romantic $curName) -join "`r`n`r`n" | Set-Content -Path $txtPath -Encoding UTF8
        }
    }

    Write-Host "Opening Notepad..." -ForegroundColor Cyan
    Write-Host "Tip: Separate each paragraph with an empty line." -ForegroundColor DarkGray
    Write-Host "Tip: You can use [NAME] anywhere to auto-insert the recipient's name." -ForegroundColor DarkGray
    Write-Host "When finished, SAVE and CLOSE Notepad to apply changes." -ForegroundColor Yellow
    Write-Host ""

    Start-Process notepad.exe -ArgumentList "`"$txtPath`"" -Wait

    if (Test-Path $txtPath) {
        $txt = Get-Content -Path $txtPath -Raw -Encoding UTF8
        $splitLines = $txt.Split([string[]]@("`r`n`r`n", "`n`n"), [System.StringSplitOptions]::RemoveEmptyEntries)
        $paras = @()
        foreach ($line in $splitLines) {
            if (-not [string]::IsNullOrWhiteSpace($line.Trim())) {
                $paras += $line.Trim()
            }
        }
        if ($paras.Count -gt 0) {
            Set-LetterInHtml -Paragraphs @($paras) -RecipientName $curName
            Write-Host ""
            $push = Read-Host "Commit and push updated letter to GitHub? (Y/N)"
            if ($push -match '^[Yy]') {
                $b = (git branch --show-current).Trim()
                git add marya.html letter.txt
                git commit -m "Update letter text in bouquet for $curName"
                git push origin $b
                Write-Host "Pushed updated letter to GitHub!" -ForegroundColor Green
            }
        }
    }
}

function Choose-LetterPresetMenu([string]$RecipientName) {
    if ([string]::IsNullOrWhiteSpace($RecipientName)) { $RecipientName = Get-CurrentRecipientName }
    Write-Host ""
    Write-Host "Select Letter Style:" -ForegroundColor Cyan
    Write-Host "  [1] Sweet & Romantic (Loving, heartwarming, caring - Recommended)" -ForegroundColor Green
    Write-Host "  [2] Heartfelt Appreciation (Thankful, supportive, cheering her on)" -ForegroundColor White
    Write-Host "  [3] Birthday / Celebration (Radiant, joy, wishing the best year)" -ForegroundColor White
    Write-Host "  [4] Nostalgic / Poetic (The classic bittersweet memory letter)" -ForegroundColor White
    Write-Host "  [5] Open in Notepad to write your own custom words" -ForegroundColor Yellow
    Write-Host "  [6] Keep current letter as is" -ForegroundColor DarkGray
    $sel = Read-Host "Choice [1-6]"

    switch ($sel) {
        "1" { Set-LetterInHtml -Paragraphs (Get-Preset-Romantic $RecipientName) -RecipientName $RecipientName }
        "2" { Set-LetterInHtml -Paragraphs (Get-Preset-Appreciation $RecipientName) -RecipientName $RecipientName }
        "3" { Set-LetterInHtml -Paragraphs (Get-Preset-Celebration $RecipientName) -RecipientName $RecipientName }
        "4" { Set-LetterInHtml -Paragraphs (Get-Preset-Nostalgic $RecipientName) -RecipientName $RecipientName }
        "5" { Edit-LetterInNotepad }
        default { Write-Host "Kept existing letter." -ForegroundColor DarkGray }
    }
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

    $htmlFile = Join-Path $RepoDir "marya.html"
    $raw = Get-Content -Path $htmlFile -Raw -Encoding UTF8
    $pattern = '(?s)<div class="letter-text" id="loveLetterText">(.*?)</div>\s*<div class="edit-controls">'
    $match = [regex]::Match($raw, $pattern)
    if ($match.Success) {
        $inner = $match.Groups[1].Value
        $inner = [regex]::Replace($inner, '(?s)<div class="polaroid">.*?</div>', '')
        $paras = [regex]::Matches($inner, '(?s)<p>(.*?)</p>') | ForEach-Object { $_.Groups[1].Value.Trim() }
        Set-LetterInHtml -Paragraphs @($paras) -RecipientName $RecipientName
    }

    Ensure-Dockerfile
}

function Create-NewBranch {
    Show-Header
    Write-Host "--- CREATE NEW BRANCH ---" -ForegroundColor Yellow
    $bName = Read-Host "Enter new branch name (e.g. cassy)"
    $bName = $bName.Trim()
    if ([string]::IsNullOrWhiteSpace($bName)) { return }

    git checkout -b $bName
    Update-RenderYaml $bName
    Ensure-Dockerfile
    
    $push = Read-Host "Push this branch to GitHub now? (Y/N)"
    if ($push -match '^[Yy]') {
        git add .
        git commit -m "Initialize branch $bName"
        git push -u origin $bName
    }
}

function Delete-Branch {
    Show-Header
    Write-Host "--- DELETE A BRANCH ---" -ForegroundColor Yellow
    Write-Host "Available branches:" -ForegroundColor Cyan
    git branch
    Write-Host ""
    $bName = Read-Host "Enter branch name to delete"
    $bName = $bName.Trim()
    if ([string]::IsNullOrWhiteSpace($bName)) { return }

    $currentBranch = (git branch --show-current).Trim()
    if ($bName -eq $currentBranch) {
        Write-Host "Cannot delete active branch. Switching to 'cassy' or 'main' first..." -ForegroundColor Yellow
        git checkout cassy 2>$null
        if ($LASTEXITCODE -ne 0) { git checkout main 2>$null }
    }

    git branch -D $bName
    $rem = Read-Host "Delete branch '$bName' on GitHub remote too? (Y/N)"
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
    Write-Host "This wizard sets up the branch, name, letter, and pictures in one go!" -ForegroundColor DarkGray
    Write-Host ""

    $name = Read-Host "1. Enter Recipient Name (e.g. Cassy)"
    $name = $name.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { return }

    $defaultBranch = $name.ToLower() -replace '\s+', '-'
    $branchPrompt = Read-Host "2. Enter Branch Name [Press Enter for '$defaultBranch']"
    $branchName = if ([string]::IsNullOrWhiteSpace($branchPrompt)) { $defaultBranch } else { $branchPrompt.Trim() }

    git checkout -B $branchName
    Write-Host "[OK] Checked out branch '$branchName'" -ForegroundColor Green

    Update-RenderYaml $branchName
    Ensure-Dockerfile

    Write-Host ""
    Write-Host "3. Pictures Setup:" -ForegroundColor Cyan
    Write-Host "   - Enter Desktop folder name (e.g. photos or C:\Users\corte\Desktop\pics)"
    Write-Host "   - Or drag & drop files/folder here"
    Write-Host "   - Or press Enter to keep current photos"
    $photoPath = Read-Host "Photo path"
    if (-not [string]::IsNullOrWhiteSpace($photoPath)) {
        Import-PicturesFromPath -SourcePath $photoPath -RecipientName $name
    }

    Write-Host ""
    Write-Host "4. Letter Selection:" -ForegroundColor Cyan
    Choose-LetterPresetMenu -RecipientName $name

    Write-Host ""
    $doPush = Read-Host "Commit and push to GitHub now? (Y/N)"
    if ($doPush -match '^[Yy]') {
        git add .
        git commit -m "Customize bouquet gift and letter for $name"
        git push -u origin $branchName
        Write-Host ""
        Write-Host "SUCCESS! Pushed to GitHub on branch '$branchName'!" -ForegroundColor Green
    }
}

function Custom-PicturesOnly {
    Show-Header
    Write-Host "--- IMPORT PICTURES FROM DESKTOP PATH ---" -ForegroundColor Yellow
    $currentName = Get-CurrentRecipientName
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
        $newName = $newName.Trim()
        $htmlFile = Join-Path $RepoDir "marya.html"
        $raw = Get-Content -Path $htmlFile -Raw -Encoding UTF8
        $pattern = '(?s)<div class="letter-text" id="loveLetterText">(.*?)</div>\s*<div class="edit-controls">'
        $match = [regex]::Match($raw, $pattern)
        if ($match.Success) {
            $inner = $match.Groups[1].Value
            $inner = [regex]::Replace($inner, '(?s)<div class="polaroid">.*?</div>', '')
            $paras = [regex]::Matches($inner, '(?s)<p>(.*?)</p>') | ForEach-Object { $_.Groups[1].Value.Trim() }
            Set-LetterInHtml -Paragraphs @($paras) -RecipientName $newName
        }

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

if ($Action) { return }

while ($true) {
    Show-Header
    Write-Host "  [1] Quick Setup (New Person: Branch + Name + Letter + Photos + Push)" -ForegroundColor Green
    Write-Host "  [2] Create a New Branch" -ForegroundColor White
    Write-Host "  [3] Delete a Branch (Local and/or Remote)" -ForegroundColor White
    Write-Host "  [4] Switch / Checkout Branch" -ForegroundColor White
    Write-Host "  [5] Change / Edit Letter Content (Notepad or Presets)" -ForegroundColor Yellow
    Write-Host "  [6] Change Recipient Name" -ForegroundColor White
    Write-Host "  [7] Import Pictures from Desktop Path" -ForegroundColor White
    Write-Host "  [8] Commit & Push Current Branch to GitHub" -ForegroundColor White
    Write-Host "  [9] Preview / Test Locally in Browser" -ForegroundColor White
    Write-Host "  [0] Exit" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Select an option [0-9]"

    switch ($choice) {
        "1" { Quick-Setup; Pause }
        "2" { Create-NewBranch; Pause }
        "3" { Delete-Branch; Pause }
        "4" { Switch-Branch; Pause }
        "5" {
            Show-Header
            Write-Host "--- CUSTOMIZE LETTER CONTENT ---" -ForegroundColor Yellow
            $curName = Get-CurrentRecipientName
            Choose-LetterPresetMenu $curName
            $commit = Read-Host "Commit and push updated letter to GitHub? (Y/N)"
            if ($commit -match '^[Yy]') {
                $b = (git branch --show-current).Trim()
                git add marya.html letter.txt 2>$null
                git commit -m "Update bouquet letter for $curName"
                git push origin $b
            }
            Pause
        }
        "6" { Custom-NameOnly; Pause }
        "7" { Custom-PicturesOnly; Pause }
        "8" {
            $b = (git branch --show-current).Trim()
            git add .
            $msg = Read-Host "Commit message [Enter for default]"
            if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "Update bouquet gift" }
            git commit -m $msg
            git push -u origin $b
            Pause
        }
        "9" { Test-Locally }
        "0" { break }
        default { Write-Host "Invalid choice, please try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
