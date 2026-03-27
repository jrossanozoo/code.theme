Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$xmlPath = Join-Path $root 'temas.xml'
$vsDarkRoot = Join-Path $root 'vsDark'
$gitHubDarkRoot = Join-Path $root 'GitHubDark'
$configRoot = Join-Path $root '.config'

function ConvertTo-DisplayName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'Theme name cannot be empty.'
    }

    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    return $textInfo.ToTitleCase($Name.ToLowerInvariant().Replace('-', ' ').Replace('_', ' '))
}

function Normalize-HexColor {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $null
    }

    if ($trimmed -match '^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') {
        return $trimmed.ToUpperInvariant()
    }

    return $null
}

function Get-RgbFromHex {
    param([string]$Hex)

    $normalized = Normalize-HexColor $Hex
    if (-not $normalized) {
        throw "Invalid color '$Hex'."
    }

    return @(
        [Convert]::ToInt32($normalized.Substring(1, 2), 16),
        [Convert]::ToInt32($normalized.Substring(3, 2), 16),
        [Convert]::ToInt32($normalized.Substring(5, 2), 16)
    )
}

function Get-HexFromRgb {
    param(
        [int]$Red,
        [int]$Green,
        [int]$Blue
    )

    return ('#{0:X2}{1:X2}{2:X2}' -f $Red, $Green, $Blue)
}

function Blend-Color {
    param(
        [string]$From,
        [string]$To,
        [double]$RatioTo
    )

    $ratio = [Math]::Max(0.0, [Math]::Min(1.0, [double]$RatioTo))
    $fromRgb = Get-RgbFromHex $From
    $toRgb = Get-RgbFromHex $To

    $red = [Math]::Round(($fromRgb[0] * (1 - $ratio)) + ($toRgb[0] * $ratio))
    $green = [Math]::Round(($fromRgb[1] * (1 - $ratio)) + ($toRgb[1] * $ratio))
    $blue = [Math]::Round(($fromRgb[2] * (1 - $ratio)) + ($toRgb[2] * $ratio))

    return Get-HexFromRgb -Red $red -Green $green -Blue $blue
}

function Set-Alpha {
    param(
        [string]$Hex,
        [string]$Alpha
    )

    $normalized = Normalize-HexColor $Hex
    if (-not $normalized) {
        throw "Invalid color '$Hex'."
    }

    if ($Alpha -notmatch '^[0-9A-Fa-f]{2}$') {
        throw "Invalid alpha '$Alpha'."
    }

    return ($normalized.Substring(0, 7) + $Alpha.ToUpperInvariant())
}

function Get-ContrastForeground {
    param([string]$Hex)

    $rgb = Get-RgbFromHex $Hex
    $luminance = ((0.299 * $rgb[0]) + (0.587 * $rgb[1]) + (0.114 * $rgb[2])) / 255
    if ($luminance -ge 0.62) {
        return '#111111'
    }

    return '#FFFFFF'
}

function Build-WorkbenchColors {
    param(
        [string]$Principal,
        [AllowNull()][string]$DiffRemoved,
        [AllowNull()][string]$DiffAdded
    )

    $principal = Normalize-HexColor $Principal
    if (-not $principal) {
        throw 'Principal color is required and must be a valid hex color.'
    }

    $principalDark = Blend-Color $principal '#000000' 0.32
    $principalDarker = Blend-Color $principal '#000000' 0.52
    $principalLight = Blend-Color $principal '#FFFFFF' 0.22
    $principalSoft = Blend-Color $principal '#FFFFFF' 0.38
    $notificationBackground = Blend-Color '#111111' $principal 0.16
    $foreground = Get-ContrastForeground $principalDark
    $badgeForeground = Get-ContrastForeground $principal

    $colors = [ordered]@{
        'focusBorder' = $principalLight
        'activityBar.background' = $principalDark
        'activityBar.foreground' = $foreground
        'activityBar.border' = $principalDarker
        'activityBar.activeBorder' = $principalLight
        'activityBarBadge.background' = $principal
        'activityBarBadge.foreground' = $badgeForeground
        'titleBar.activeBackground' = $principalDark
        'titleBar.activeForeground' = $foreground
        'titleBar.inactiveBackground' = $principalDarker
        'titleBar.inactiveForeground' = $principalSoft
        'titleBar.border' = $principalDarker
        'statusBar.background' = $principal
        'statusBar.foreground' = $badgeForeground
        'statusBar.border' = $principalLight
        'statusBar.noFolderBackground' = $principalDark
        'statusBar.noFolderForeground' = $foreground
        'statusBarItem.hoverBackground' = Set-Alpha $principalLight '33'
        'menubar.selectionBackground' = Set-Alpha $principal '33'
        'menubar.selectionForeground' = $foreground
        'menu.selectionBackground' = Set-Alpha $principal '33'
        'menu.selectionForeground' = $foreground
        'menu.border' = $principalDarker
        'commandCenter.activeBackground' = Set-Alpha $principal '30'
        'commandCenter.activeForeground' = $foreground
        'notificationCenterHeader.background' = $principalDark
        'notificationCenterHeader.foreground' = $foreground
        'notifications.background' = $notificationBackground
        'notifications.foreground' = '#FFFFFF'
        'notifications.border' = $principal
        'panel.border' = $principalDarker
        'sideBar.border' = $principalDarker
        'editorGroup.border' = $principalDarker
        'pickerGroup.border' = $principal
        'inputOption.activeBorder' = $principalLight
        'badge.background' = $principal
        'badge.foreground' = $badgeForeground
        'progressBar.background' = $principalLight
        'toolbar.hoverBackground' = Set-Alpha $principal '22'
        'toolbar.activeBackground' = Set-Alpha $principal '33'
    }

    $removed = Normalize-HexColor $DiffRemoved
    if ($removed) {
        $colors['diffEditor.removedLineBackground'] = Set-Alpha $removed '1F'
        $colors['diffEditor.removedTextBackground'] = Set-Alpha $removed '44'
        $colors['diffEditorGutter.removedLineBackground'] = Set-Alpha $removed '66'
    }

    $added = Normalize-HexColor $DiffAdded
    if ($added) {
        $colors['diffEditor.insertedLineBackground'] = Set-Alpha $added '1F'
        $colors['diffEditor.insertedTextBackground'] = Set-Alpha $added '44'
        $colors['diffEditorGutter.insertedLineBackground'] = Set-Alpha $added '66'
    }

    return $colors
}

function Build-TokenRules {
    param(
        [AllowNull()][string]$Syntax,
        [AllowNull()][string]$Literal
    )

    $rules = New-Object System.Collections.Generic.List[object]
    $syntaxColor = Normalize-HexColor $Syntax
    $literalColor = Normalize-HexColor $Literal

    if ($syntaxColor) {
        $rules.Add([ordered]@{
            name = 'Language syntax'
            scope = @(
                'keyword',
                'keyword.control',
                'keyword.operator.expression',
                'keyword.operator.new',
                'keyword.operator.word',
                'storage',
                'storage.type',
                'storage.modifier'
            )
            settings = [ordered]@{
                foreground = $syntaxColor
            }
        })
    }

    if ($literalColor) {
        $rules.Add([ordered]@{
            name = 'Literal values'
            scope = @(
                'string',
                'string.quoted',
                'constant.numeric',
                'constant.language',
                'constant.character',
                'constant.escape'
            )
            settings = [ordered]@{
                foreground = $literalColor
            }
        })
    }

    return $rules
}

function Build-SemanticTokenColors {
    param(
        [AllowNull()][string]$Syntax,
        [AllowNull()][string]$Literal
    )

    $colors = [ordered]@{}
    $syntaxColor = Normalize-HexColor $Syntax
    $literalColor = Normalize-HexColor $Literal

    if ($syntaxColor) {
        $colors['keyword'] = $syntaxColor
    }

    if ($literalColor) {
        $colors['string'] = $literalColor
        $colors['number'] = $literalColor
    }

    return $colors
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $json = $Content | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Ensure-DarkPlusBase {
    param([string]$TargetPath)

    $sourceCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\resources\app\extensions\theme-defaults\themes\dark_plus.json'),
        'C:\Program Files\Microsoft VS Code\resources\app\extensions\theme-defaults\themes\dark_plus.json',
        'C:\Program Files (x86)\Microsoft VS Code\resources\app\extensions\theme-defaults\themes\dark_plus.json'
    )

    $localSource = $sourceCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($localSource) {
        Copy-Item -Path $localSource -Destination $TargetPath -Force
        return
    }

    $uri = 'https://raw.githubusercontent.com/microsoft/vscode/main/extensions/theme-defaults/themes/dark_plus.json'
    Invoke-WebRequest -Uri $uri -OutFile $TargetPath
}

function Ensure-GitHubDarkBase {
    param([string]$TargetPath)

    $extensionsPath = Join-Path $env:USERPROFILE '.vscode\extensions'
    if (-not (Test-Path $extensionsPath)) {
        throw 'GitHub Theme extension was not found under the VS Code extensions directory.'
    }

    $source = Get-ChildItem -Path $extensionsPath -Directory |
        Where-Object { $_.Name -like 'github.github-vscode-theme*' } |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'themes\dark-default.json' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if (-not $source) {
        throw 'GitHub Dark Default theme file was not found in installed extensions.'
    }

    Copy-Item -Path $source -Destination $TargetPath -Force
}

function New-ThemePackage {
    param(
        [string]$SeriesRoot,
        [string]$BaseInclude,
        [string]$Slug,
        [string]$DisplayName,
        [string]$LabelSuffix,
        [string]$ThemeFileName,
        [string]$Principal,
        [AllowNull()][string]$Syntax,
        [AllowNull()][string]$Literal,
        [AllowNull()][string]$DiffRemoved,
        [AllowNull()][string]$DiffAdded
    )

    $folder = Join-Path $SeriesRoot ("{0}-vscode-theme-1.0.0" -f $Slug)
    $themePath = Join-Path $folder (Join-Path 'theme' $ThemeFileName)
    $themeLabel = "{0} {1}" -f $DisplayName, $LabelSuffix
    $rules = @(Build-TokenRules -Syntax $Syntax -Literal $Literal)
    $semanticTokenColors = Build-SemanticTokenColors -Syntax $Syntax -Literal $Literal

    $packageJson = [ordered]@{
        name = ("{0}-{1}" -f $Slug, $LabelSuffix.ToLowerInvariant().Replace('+', 'plus').Replace(' ', '-'))
        displayName = $themeLabel
        version = '1.0.0'
        engines = [ordered]@{
            vscode = '^1.85.0'
        }
        categories = @('Themes')
        contributes = [ordered]@{
            themes = @(
                [ordered]@{
                    label = $themeLabel
                    uiTheme = 'vs-dark'
                    path = "./theme/$ThemeFileName"
                }
            )
        }
    }

    $themeJson = [ordered]@{
        '$schema' = 'vscode://schemas/color-theme'
        name = $themeLabel
        include = $BaseInclude
        semanticHighlighting = $true
        colors = Build-WorkbenchColors -Principal $Principal -DiffRemoved $DiffRemoved -DiffAdded $DiffAdded
    }

    if ($rules.Count -gt 0) {
        $themeJson.tokenColors = @($rules)
    }

    if ($semanticTokenColors.Count -gt 0) {
        $themeJson.semanticTokenColors = $semanticTokenColors
    }

    Write-JsonFile -Path (Join-Path $folder 'package.json') -Content $packageJson
    Write-JsonFile -Path $themePath -Content $themeJson
}

function New-WorkspaceFile {
    param(
        [string]$BaseThemeName,
        [string]$OutputPath,
        [string]$Principal,
        [AllowNull()][string]$Syntax,
        [AllowNull()][string]$Literal,
        [AllowNull()][string]$DiffRemoved,
        [AllowNull()][string]$DiffAdded
    )

    $workspace = [ordered]@{
        folders = @(
            [ordered]@{
                path = '..'
            }
        )
        settings = [ordered]@{
            'workbench.colorTheme' = $BaseThemeName
            'workbench.colorCustomizations' = Build-WorkbenchColors -Principal $Principal -DiffRemoved $DiffRemoved -DiffAdded $DiffAdded
        }
        'zoo-tool-kit.showExtensionRecommendations' = $false
    }

    $rules = @(Build-TokenRules -Syntax $Syntax -Literal $Literal)
    if ($rules.Count -gt 0) {
        $workspace.settings['editor.tokenColorCustomizations'] = [ordered]@{
            textMateRules = @($rules)
        }
    }

    $semanticTokenColors = Build-SemanticTokenColors -Syntax $Syntax -Literal $Literal
    if ($semanticTokenColors.Count -gt 0) {
        $workspace.settings['editor.semanticTokenColorCustomizations'] = [ordered]@{
            enabled = $true
            rules = $semanticTokenColors
        }
    }

    Write-JsonFile -Path $OutputPath -Content $workspace
}

[xml]$xml = Get-Content -Path $xmlPath
$themeEntries = @($xml.VFPData.temas)

if ($themeEntries.Count -eq 0) {
    throw 'No themes were found in temas.xml.'
}

New-Item -ItemType Directory -Path (Join-Path $vsDarkRoot '_base') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $gitHubDarkRoot '_base') -Force | Out-Null
New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

$darkPlusBasePath = Join-Path $vsDarkRoot '_base\dark-plus.json'
$gitHubDarkBasePath = Join-Path $gitHubDarkRoot '_base\github-dark-default.json'

Ensure-DarkPlusBase -TargetPath $darkPlusBasePath
Ensure-GitHubDarkBase -TargetPath $gitHubDarkBasePath

foreach ($entry in $themeEntries) {
    $slug = $entry.tema.Trim().ToLowerInvariant()
    $displayName = ConvertTo-DisplayName $slug
    $principal = Normalize-HexColor $entry.principal

    if (-not $principal) {
        throw "Theme '$slug' does not have a valid principal color."
    }

    $syntax = Normalize-HexColor $entry.sintaxis
    $literal = Normalize-HexColor $entry.literal
    $diffRemoved = Normalize-HexColor $entry.diff1
    $diffAdded = Normalize-HexColor $entry.diff2

    New-ThemePackage `
        -SeriesRoot $vsDarkRoot `
        -BaseInclude '../../_base/dark-plus.json' `
        -Slug $slug `
        -DisplayName $displayName `
        -LabelSuffix 'Dark+' `
        -ThemeFileName ("{0}-dark-plus-color-theme.json" -f $slug) `
        -Principal $principal `
        -Syntax $syntax `
        -Literal $literal `
        -DiffRemoved $diffRemoved `
        -DiffAdded $diffAdded

    New-ThemePackage `
        -SeriesRoot $gitHubDarkRoot `
        -BaseInclude '../../_base/github-dark-default.json' `
        -Slug $slug `
        -DisplayName $displayName `
        -LabelSuffix 'GitHub Dark' `
        -ThemeFileName ("{0}-github-dark-color-theme.json" -f $slug) `
        -Principal $principal `
        -Syntax $syntax `
        -Literal $literal `
        -DiffRemoved $diffRemoved `
        -DiffAdded $diffAdded

    New-WorkspaceFile `
        -BaseThemeName 'Dark+' `
        -OutputPath (Join-Path $configRoot ("{0}.dark.code-workspace" -f $slug)) `
        -Principal $principal `
        -Syntax $syntax `
        -Literal $literal `
        -DiffRemoved $diffRemoved `
        -DiffAdded $diffAdded

    New-WorkspaceFile `
        -BaseThemeName 'GitHub Dark Default' `
        -OutputPath (Join-Path $configRoot ("{0}.github.code-workspace" -f $slug)) `
        -Principal $principal `
        -Syntax $syntax `
        -Literal $literal `
        -DiffRemoved $diffRemoved `
        -DiffAdded $diffAdded
}

Write-Host ("Generated {0} themes in vsDark, {0} themes in GitHubDark, and {1} workspace files." -f $themeEntries.Count, ($themeEntries.Count * 2))