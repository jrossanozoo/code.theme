Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Genera archivos .code-workspace a partir de temasIDE.xml (raiz del repo).
# A diferencia de generate-themes.ps1, si un tema define <barraSuperior>,
# <barraInferior> y/o <barraHerramientas>, esos colores tienen prioridad sobre
# <principal> para la barra de titulo (titleBar), la barra de estado (statusBar)
# y la barra lateral de herramientas (activityBar) respectivamente. Si alguno de
# los tres queda vacio, esa barra sigue derivandose de <principal> como hasta ahora.
# El resto de las reglas (sintaxis, literales, enlaces, comentarios, diffs) no cambia.

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $root
$xmlPath = Join-Path $repoRoot 'temasIDE.xml'
$configRoot = Join-Path $root '.config-ide'

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
        [AllowNull()][string]$BarraSuperior,
        [AllowNull()][string]$BarraInferior,
        [AllowNull()][string]$BarraHerramientas,
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

    # Barra de titulo (barra superior): usa <barraSuperior> si esta definida,
    # si no cae al mismo derivado de <principal> que usa generate-themes.ps1.
    $barraSuperior = Normalize-HexColor $BarraSuperior
    if ($barraSuperior) {
        $titleBackground = $barraSuperior
        $titleBackgroundInactive = Blend-Color $barraSuperior '#000000' 0.32
        $titleBorder = Blend-Color $barraSuperior '#000000' 0.52
        $titleForeground = Get-ContrastForeground $barraSuperior
        $titleForegroundInactive = Blend-Color $barraSuperior '#FFFFFF' 0.38
    }
    else {
        $titleBackground = $principalDark
        $titleBackgroundInactive = $principalDarker
        $titleBorder = $principalDarker
        $titleForeground = $foreground
        $titleForegroundInactive = $principalSoft
    }

    # Barra de estado (barra inferior): usa <barraInferior> si esta definida,
    # si no cae al mismo derivado de <principal> que usa generate-themes.ps1.
    $barraInferior = Normalize-HexColor $BarraInferior
    if ($barraInferior) {
        $statusBackground = $barraInferior
        $statusBorder = Blend-Color $barraInferior '#FFFFFF' 0.22
        $statusNoFolderBackground = Blend-Color $barraInferior '#000000' 0.32
        $statusForeground = Get-ContrastForeground $barraInferior
    }
    else {
        $statusBackground = $principal
        $statusBorder = $principalLight
        $statusNoFolderBackground = $principalDark
        $statusForeground = $badgeForeground
    }

    # Barra lateral de herramientas (activityBar): usa <barraHerramientas> si esta
    # definida, si no cae al mismo derivado de <principal> que usa generate-themes.ps1.
    $barraHerramientas = Normalize-HexColor $BarraHerramientas
    if ($barraHerramientas) {
        $activityBackground = $barraHerramientas
        $activityBorder = Blend-Color $barraHerramientas '#000000' 0.52
        $activityActiveBorder = Blend-Color $barraHerramientas '#FFFFFF' 0.22
        $activityForeground = Get-ContrastForeground $barraHerramientas
    }
    else {
        $activityBackground = $principalDark
        $activityBorder = $principalDarker
        $activityActiveBorder = $principalLight
        $activityForeground = $foreground
    }

    $colors = [ordered]@{
        'focusBorder' = $principalLight
        'activityBar.background' = $activityBackground
        'activityBar.foreground' = $activityForeground
        'activityBar.border' = $activityBorder
        'activityBar.activeBorder' = $activityActiveBorder
        'activityBarBadge.background' = $principal
        'activityBarBadge.foreground' = $badgeForeground
        'titleBar.activeBackground' = $titleBackground
        'titleBar.activeForeground' = $titleForeground
        'titleBar.inactiveBackground' = $titleBackgroundInactive
        'titleBar.inactiveForeground' = $titleForegroundInactive
        'titleBar.border' = $titleBorder
        'statusBar.background' = $statusBackground
        'statusBar.foreground' = $statusForeground
        'statusBar.border' = $statusBorder
        'statusBar.noFolderBackground' = $statusNoFolderBackground
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
        [AllowNull()][string]$Literal,
        [AllowNull()][string]$Link,
        [AllowNull()][string]$Comment
    )

    $rules = New-Object System.Collections.Generic.List[object]
    $syntaxColor = Normalize-HexColor $Syntax
    $literalColor = Normalize-HexColor $Literal
    $linkColor = Normalize-HexColor $Link
    $commentColor = Normalize-HexColor $Comment

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

    if ($linkColor) {
        $rules.Add([ordered]@{
            name = 'Links (Markdown + source)'
            scope = @(
                'string.other.link.title.markdown',
                'meta.link.reference.markdown',
                'meta.link.reference.def.markdown',
                'meta.link.inline.markdown',
                'markup.underline.link.markdown',
                'markup.underline.link.image.markdown',
                'markup.underline.link',
                'string.other.link'
            )
            settings = [ordered]@{
                foreground = $linkColor
            }
        })
    }

    if ($commentColor) {
        $rules.Add([ordered]@{
            name = 'Comments'
            scope = @(
                'comment',
                'comment.line',
                'comment.block',
                'comment.block.documentation',
                'comment.block.html'
            )
            settings = [ordered]@{
                foreground = $commentColor
            }
        })
    }

    return $rules
}

function Build-SemanticTokenColors {
    param(
        [AllowNull()][string]$Syntax,
        [AllowNull()][string]$Literal,
        [AllowNull()][string]$Comment
    )

    $colors = [ordered]@{}
    $syntaxColor = Normalize-HexColor $Syntax
    $literalColor = Normalize-HexColor $Literal
    $commentColor = Normalize-HexColor $Comment

    if ($syntaxColor) {
        $colors['keyword'] = $syntaxColor
    }

    if ($literalColor) {
        $colors['string'] = $literalColor
        $colors['number'] = $literalColor
    }

    if ($commentColor) {
        $colors['comment'] = $commentColor
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

function New-WorkspaceFile {
    param(
        [string]$BaseThemeName,
        [string]$OutputPath,
        [string]$Principal,
        [AllowNull()][string]$BarraSuperior,
        [AllowNull()][string]$BarraInferior,
        [AllowNull()][string]$BarraHerramientas,
        [AllowNull()][string]$Syntax,
        [AllowNull()][string]$Literal,
        [AllowNull()][string]$Link,
        [AllowNull()][string]$Comment,
        [AllowNull()][string]$DiffRemoved,
        [AllowNull()][string]$DiffAdded
    )

    $workspace = [ordered]@{
        folders = @(
            [ordered]@{
                path = '.'
            }
        )
        settings = [ordered]@{
            'workbench.colorTheme' = $BaseThemeName
            'workbench.colorCustomizations' = Build-WorkbenchColors -Principal $Principal -BarraSuperior $BarraSuperior -BarraInferior $BarraInferior -BarraHerramientas $BarraHerramientas -DiffRemoved $DiffRemoved -DiffAdded $DiffAdded
        }
        'zoo-tool-kit.showExtensionRecommendations' = $false
    }

    $rules = @(Build-TokenRules -Syntax $Syntax -Literal $Literal -Link $Link -Comment $Comment)
    if ($rules.Count -gt 0) {
        $workspace.settings['editor.tokenColorCustomizations'] = [ordered]@{
            textMateRules = @($rules)
        }
    }

    $semanticTokenColors = Build-SemanticTokenColors -Syntax $Syntax -Literal $Literal -Comment $Comment
    if ($semanticTokenColors.Count -gt 0) {
        $workspace.settings['editor.semanticTokenColorCustomizations'] = [ordered]@{
            enabled = $true
            rules = $semanticTokenColors
        }
    }

    Write-JsonFile -Path $OutputPath -Content $workspace
}

[xml]$xml = Get-Content -Path $xmlPath
$themeEntries = @($xml.VFPData.c_temas)

if ($themeEntries.Count -eq 0) {
    throw 'No themes were found in temasIDE.xml.'
}

New-Item -ItemType Directory -Path $configRoot -Force | Out-Null

foreach ($entry in $themeEntries) {
    $slug = $entry.tema.Trim().ToLowerInvariant()
    $principal = Normalize-HexColor $entry.principal

    if (-not $principal) {
        throw "Theme '$slug' does not have a valid principal color."
    }

    $syntax = Normalize-HexColor $entry.sintaxis
    $literal = Normalize-HexColor $entry.literal
    $link = Normalize-HexColor $entry.enlaces
    $comment = Normalize-HexColor $entry.comentario
    $diffRemoved = Normalize-HexColor $entry.diff1
    $diffAdded = Normalize-HexColor $entry.diff2
    $barraSuperior = Normalize-HexColor $entry.barraSuperior
    $barraInferior = Normalize-HexColor $entry.barraInferior
    $barraHerramientas = Normalize-HexColor $entry.barraHerramientas

    New-WorkspaceFile `
        -BaseThemeName 'Dark+' `
        -OutputPath (Join-Path $configRoot ("{0}.dark.code-workspace" -f $slug)) `
        -Principal $principal `
        -BarraSuperior $barraSuperior `
        -BarraInferior $barraInferior `
        -BarraHerramientas $barraHerramientas `
        -Syntax $syntax `
        -Literal $literal `
        -Link $link `
        -Comment $comment `
        -DiffRemoved $diffRemoved `
        -DiffAdded $diffAdded

    New-WorkspaceFile `
        -BaseThemeName 'GitHub Dark Default' `
        -OutputPath (Join-Path $configRoot ("{0}.github.code-workspace" -f $slug)) `
        -Principal $principal `
        -BarraSuperior $barraSuperior `
        -BarraInferior $barraInferior `
        -BarraHerramientas $barraHerramientas `
        -Syntax $syntax `
        -Literal $literal `
        -Link $link `
        -Comment $comment `
        -DiffRemoved $diffRemoved `
        -DiffAdded $diffAdded
}

Write-Host ("Generated {0} workspace files in {1}." -f ($themeEntries.Count * 2), $configRoot)
