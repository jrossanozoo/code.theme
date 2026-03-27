# generate-themes.ps1
# Generates vsDark and GitHubDark theme extensions + .config workspace files
# Source of truth: temas.xml

param(
    [string]$Root = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helper: parse hex color "#RRGGBB" -> [R,G,B]
function Parse-Hex([string]$hex) {
    $h = $hex.TrimStart('#')
    if ($h.Length -ne 6) { throw "Invalid hex color: $hex" }
    return @([Convert]::ToInt32($h.Substring(0,2),16),
             [Convert]::ToInt32($h.Substring(2,2),16),
             [Convert]::ToInt32($h.Substring(4,2),16))
}

# Helper: clamp int 0-255
function Clamp([int]$v) { [Math]::Max(0,[Math]::Min(255,$v)) }

# Helper: [R,G,B] -> "#RRGGBB"
function To-Hex([int[]]$rgb) {
    return "#{0:X2}{1:X2}{2:X2}" -f $rgb[0],$rgb[1],$rgb[2]
}

# Lighten a color by adding a fixed amount to each channel
function Lighten([string]$hex,[int]$amount) {
    $rgb = Parse-Hex $hex
    return To-Hex @((Clamp($rgb[0]+$amount)),(Clamp($rgb[1]+$amount)),(Clamp($rgb[2]+$amount)))
}

# Darken a color by subtracting a fixed amount
function Darken([string]$hex,[int]$amount) {
    $rgb = Parse-Hex $hex
    return To-Hex @((Clamp($rgb[0]-$amount)),(Clamp($rgb[1]-$amount)),(Clamp($rgb[2]-$amount)))
}

# Mix color with white to get a pastel accent
function Accent([string]$hex) {
    $rgb = Parse-Hex $hex
    # Push each channel toward 220
    $r = Clamp([int](($rgb[0]*0.4) + (220*0.6)))
    $g = Clamp([int](($rgb[1]*0.4) + (220*0.6)))
    $b = Clamp([int](($rgb[2]*0.4) + (220*0.6)))
    return To-Hex @($r,$g,$b)
}

# Append alpha hex to a color: "#RRGGBB" -> "#RRGGBBAA"
function WithAlpha([string]$hex,[string]$alpha) {
    return $hex.TrimEnd() + $alpha
}

# Return a color with 25% opacity appended
function WithAlpha25([string]$hex) { return WithAlpha $hex "40" }
function WithAlpha50([string]$hex) { return WithAlpha $hex "80" }

# Validate if a string is a proper hex color
function Is-HexColor([string]$val) {
    return ($val -match '^#[0-9A-Fa-f]{6}$')
}

# ---------------------------------------------------------------------------
# Build the UI color palette for a given principal color
function Build-Palette([string]$principal) {
    $active    = $principal                  # active chrome bg
    $dark      = Darken  $principal 20       # border / inactive bg
    $darker    = Darken  $principal 35       # deeper border
    $mid       = Lighten $principal 25       # sidebar bg / status bar
    $accent    = Accent  $principal          # accent / active border
    $hover     = Lighten $principal 40       # hover state

    return @{
        active   = $active
        dark     = $dark
        darker   = $darker
        mid      = $mid
        accent   = $accent
        hover    = $hover
        white    = "#FFFFFF"
        inactive = "#A0A0A0"
    }
}

# ---------------------------------------------------------------------------
# Build the colors block for a theme JSON (UI chrome only)
function Build-Colors([hashtable]$p) {
    return [ordered]@{
        # Activity Bar
        "activityBar.background"          = $p.active
        "activityBar.foreground"          = $p.white
        "activityBar.border"              = $p.darker
        "activityBar.activeBorder"        = $p.accent
        "activityBarBadge.background"     = $p.accent
        "activityBarBadge.foreground"     = "#000000"

        # Title Bar
        "titleBar.activeBackground"       = $p.active
        "titleBar.activeForeground"       = $p.white
        "titleBar.inactiveBackground"     = $p.dark
        "titleBar.inactiveForeground"     = $p.inactive
        "titleBar.border"                 = $p.darker

        # Menu Bar
        "menubar.selectionBackground"     = $p.mid
        "menubar.selectionForeground"     = $p.white
        "menu.background"                 = $p.active
        "menu.foreground"                 = $p.white
        "menu.selectionBackground"        = $p.mid
        "menu.selectionForeground"        = $p.white
        "menu.border"                     = $p.dark

        # Status Bar
        "statusBar.background"            = $p.mid
        "statusBar.foreground"            = $p.white
        "statusBar.border"                = $p.dark
        "statusBar.noFolderBackground"    = $p.active
        "statusBarItem.hoverBackground"   = $p.hover

        # Tabs
        "tab.border"                      = $p.dark
        "tab.activeBorder"                = $p.accent
        "tab.unfocusedActiveBorder"       = $p.mid

        # Editor Group / Panel borders
        "editorGroup.border"              = $p.dark
        "panel.border"                    = $p.dark

        # Focus border
        "focusBorder"                     = $p.accent

        # Input
        "input.border"                    = $p.dark

        # Buttons
        "button.background"               = $p.mid
        "button.hoverBackground"          = $p.hover
    }
}

# ---------------------------------------------------------------------------
# Build tokenColors array for optional syntax overrides
function Build-TokenColors([string]$sintaxis,[string]$literal,[string]$diff1,[string]$diff2) {
    $tokens = @()

    if (Is-HexColor $sintaxis) {
        $tokens += [ordered]@{
            name   = "Language Syntax / Keywords"
            scope  = @("keyword","storage.type","storage.modifier","keyword.control")
            settings = @{ foreground = $sintaxis }
        }
    }

    if (Is-HexColor $literal) {
        $tokens += [ordered]@{
            name   = "String Literals"
            scope  = @("string","string.quoted","constant.other.symbol")
            settings = @{ foreground = $literal }
        }
    }

    return $tokens
}

# ---------------------------------------------------------------------------
# Build workbench color customizations for diff (added/removed in diff editor)
function Build-DiffColors([string]$diff1,[string]$diff2) {
    $colors = [ordered]@{}

    if (Is-HexColor $diff1) {
        # diff1 = removed lines
        $colors["diffEditor.removedLineBackground"]  = WithAlpha25 $diff1
        $colors["diffEditor.removedTextBackground"]  = WithAlpha50 $diff1
    }

    if (Is-HexColor $diff2) {
        # diff2 = added lines
        $colors["diffEditor.insertedLineBackground"] = WithAlpha25 $diff2
        $colors["diffEditor.insertedTextBackground"] = WithAlpha50 $diff2
    }

    return $colors
}

# ---------------------------------------------------------------------------
# Write a theme extension folder
function Write-Theme {
    param(
        [string]$SeriesDir,    # e.g. <Root>/vsDark
        [string]$Name,         # e.g. forest
        [string]$BaseTheme,    # "Dark+" or "GitHub Dark"
        [string]$BaseToken,    # used in include: "__dark-plus" or "__github-dark"
        [hashtable]$Palette,
        [string]$Sintaxis,
        [string]$Literal,
        [string]$Diff1,
        [string]$Diff2
    )

    $folderName = "$Name-vscode-theme-1.0.0"
    $extDir     = Join-Path $SeriesDir $folderName
    $themeDir   = Join-Path $extDir "theme"

    $null = New-Item -ItemType Directory -Force -Path $themeDir

    # --- package.json ---
    $labelSuffix = if ($BaseTheme -eq "Dark+") { "Dark+" } else { "GitHub Dark" }
    $label       = "$Name ($labelSuffix)"
    $pkgName     = "$Name-$($BaseToken.TrimStart('_'))"

    $pkg = [ordered]@{
        name        = $pkgName
        displayName = $label
        version     = "1.0.0"
        engines     = @{ vscode = "^1.85.0" }
        categories  = @("Themes")
        contributes = @{
            themes = @(
                [ordered]@{
                    label    = $label
                    uiTheme  = "vs-dark"
                    path     = "./theme/$Name.json"
                }
            )
        }
    }

    $pkg | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $extDir "package.json") -Encoding UTF8

    # --- theme JSON ---
    $uiColors   = Build-Colors $Palette
    $diffColors = Build-DiffColors $Diff1 $Diff2
    # merge diff into ui colors
    foreach ($k in $diffColors.Keys) { $uiColors[$k] = $diffColors[$k] }

    $tokenColors = @(Build-TokenColors $Sintaxis $Literal $Diff1 $Diff2)

    $themeObj = [ordered]@{
        name    = $label
        type    = "dark"
        include = "./../../_base/$BaseToken.json"
        colors  = $uiColors
    }

    if ($tokenColors.Count -gt 0) {
        $themeObj["tokenColors"] = $tokenColors
    }

    $themeJson = $themeObj | ConvertTo-Json -Depth 20
    Set-Content -Path (Join-Path $themeDir "$Name.json") -Value $themeJson -Encoding UTF8

    return $label
}

# ---------------------------------------------------------------------------
# Write a .code-workspace file
function Write-Workspace {
    param(
        [string]$ConfigDir,
        [string]$Name,
        [string]$ThemeLabel,
        [string]$Suffix,       # "dark" or "github"
        [hashtable]$Palette,
        [string]$Sintaxis,
        [string]$Literal,
        [string]$Diff1,
        [string]$Diff2
    )

    $null = New-Item -ItemType Directory -Force -Path $ConfigDir

    $colorCustom = [ordered]@{}

    # Activity Bar
    $colorCustom["activityBar.background"]      = $Palette.active
    $colorCustom["activityBar.foreground"]      = $Palette.white
    $colorCustom["activityBar.border"]          = $Palette.darker
    $colorCustom["activityBar.activeBorder"]    = $Palette.accent
    $colorCustom["activityBarBadge.background"] = $Palette.accent
    $colorCustom["activityBarBadge.foreground"] = "#000000"

    # Title Bar
    $colorCustom["titleBar.activeBackground"]   = $Palette.active
    $colorCustom["titleBar.activeForeground"]   = $Palette.white
    $colorCustom["titleBar.inactiveBackground"] = $Palette.dark
    $colorCustom["titleBar.inactiveForeground"] = $Palette.inactive
    $colorCustom["titleBar.border"]             = $Palette.darker

    # Status Bar
    $colorCustom["statusBar.background"]        = $Palette.mid
    $colorCustom["statusBar.foreground"]        = $Palette.white
    $colorCustom["statusBar.border"]            = $Palette.dark
    $colorCustom["statusBar.noFolderBackground"]   = $Palette.active
    $colorCustom["statusBarItem.hoverBackground"]  = $Palette.hover

    # Diff
    $diffColors = Build-DiffColors $Diff1 $Diff2
    foreach ($k in $diffColors.Keys) { $colorCustom[$k] = $diffColors[$k] }

    # Token color customizations
    $tokenSection = [ordered]@{}
    if (Is-HexColor $Sintaxis) {
        $tokenSection["textMateRules"] = @(
            [ordered]@{
                scope    = @("keyword","storage.type","storage.modifier","keyword.control")
                settings = @{ foreground = $Sintaxis }
            }
            [ordered]@{
                scope    = @("string","string.quoted","constant.other.symbol")
                settings = @{ foreground = $Literal }
            }
        ) | Where-Object { Is-HexColor $_.settings.foreground }
    }

    $ws = [ordered]@{
        folders  = @(@{ path = ".." })
        settings = [ordered]@{
            "workbench.colorTheme"          = $ThemeLabel
            "workbench.colorCustomizations" = $colorCustom
        }
    }

    if ($tokenSection.Count -gt 0 -and $tokenSection["textMateRules"].Count -gt 0) {
        $ws.settings["editor.tokenColorCustomizations"] = $tokenSection
    }

    # Add zoo setting
    $ws.settings["zoo-tool-kit.showExtensionRecommendations"] = $false

    $wsJson = $ws | ConvertTo-Json -Depth 20
    $fileName = "$Name.$Suffix.code-workspace"
    Set-Content -Path (Join-Path $ConfigDir $fileName) -Value $wsJson -Encoding UTF8

    Write-Host "  Workspace: $fileName"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

[xml]$xml = Get-Content (Join-Path $Root "temas.xml") -Encoding UTF8

$vsDarkDir    = Join-Path $Root "vsDark"
$githubDir    = Join-Path $Root "GitHubDark"
$configDir    = Join-Path $Root ".config"

# Ensure series root dirs exist
$null = New-Item -ItemType Directory -Force -Path $vsDarkDir
$null = New-Item -ItemType Directory -Force -Path $githubDir
$null = New-Item -ItemType Directory -Force -Path $configDir

foreach ($t in $xml.VFPData.temas) {

    $name      = $t.tema.Trim().ToLower()
    $principal = $t.principal.Trim()
    $sintaxis  = if ($t.sintaxis) { $t.sintaxis.Trim() } else { "" }
    $literal   = if ($t.literal)  { $t.literal.Trim()  } else { "" }
    $diff1     = if ($t.diff1)    { $t.diff1.Trim()    } else { "" }
    $diff2     = if ($t.diff2)    { $t.diff2.Trim()    } else { "" }

    if (-not (Is-HexColor $principal)) {
        Write-Warning "Tema '$name': principal '$principal' is not a valid hex color. Skipping."
        continue
    }

    $palette = Build-Palette $principal

    Write-Host "Processing theme: $name  ($principal)"

    # --- vsDark series ---
    $labelDark = Write-Theme `
        -SeriesDir  $vsDarkDir `
        -Name       $name `
        -BaseTheme  "Dark+" `
        -BaseToken  "__dark-plus" `
        -Palette    $palette `
        -Sintaxis   $sintaxis `
        -Literal    $literal `
        -Diff1      $diff1 `
        -Diff2      $diff2

    Write-Workspace `
        -ConfigDir  $configDir `
        -Name       $name `
        -ThemeLabel $labelDark `
        -Suffix     "dark" `
        -Palette    $palette `
        -Sintaxis   $sintaxis `
        -Literal    $literal `
        -Diff1      $diff1 `
        -Diff2      $diff2

    # --- GitHubDark series ---
    $labelGH = Write-Theme `
        -SeriesDir  $githubDir `
        -Name       $name `
        -BaseTheme  "GitHub Dark" `
        -BaseToken  "__github-dark" `
        -Palette    $palette `
        -Sintaxis   $sintaxis `
        -Literal    $literal `
        -Diff1      $diff1 `
        -Diff2      $diff2

    Write-Workspace `
        -ConfigDir  $configDir `
        -Name       $name `
        -ThemeLabel $labelGH `
        -Suffix     "github" `
        -Palette    $palette `
        -Sintaxis   $sintaxis `
        -Literal    $literal `
        -Diff1      $diff1 `
        -Diff2      $diff2
}

Write-Host ""
Write-Host "Done! Generated themes in vsDark/ and GitHubDark/, workspaces in .config/"
