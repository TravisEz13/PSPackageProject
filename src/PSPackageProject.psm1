# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

#region Private implementation functions

function RunPwshCommandInSubprocess
{
    param(
        [string]
        $Command
    )

    if (-not $script:pwshPath)
    {
        $script:pwshPath = (Get-Process -Id $PID).Path
    }

    & $script:pwshPath -NoProfile -NoLogo -Command $Command
}

function RunProjectBuild
{
    param(
        [string]
        $ProjectRoot
    )

    & "$ProjectRoot/build.ps1" -Clean
}

function GetHelpPath
{
    param(
        [cultureinfo]
        $Culture,

        [string]
        $ProjectRoot
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    $cultureName = $Culture.Name

    return "$ProjectRoot/help/$cultureName"
}

function GetOutputModulePath
{
    param(
        [string]
        $ProjectRoot,

        [string]
        $ModuleName
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    return "$ProjectRoot/out/$ModuleName"
}

function HasCmdletHelp
{
    param(
        [string]
        $HelpResourcePath
    )

    if (-not (Test-Path -Path $HelpResourcePath))
    {
        return $false
    }

    $files = Get-ChildItem -Path $HelpResourcePath -ErrorAction Ignore |
        Where-Object Name -Like '*.md' |
        Where-Object Name -NotLike 'about_*'

    return $files.Count -gt 0
}

#endregion Private implementation functions

#region Public commands

function Invoke-PSPackageProjectTest
{
    param(
        [Parameter()]
        [ValidateSet("Functional", "StaticAnalysis")]
        [string]
        $Type
    )

    ## TODO implement calling tests
}

<#
.SYNOPSIS
Generates help file stubs.

.DESCRIPTION
Generates stubs for about_*.md help documentation for a given module.

.PARAMETER ProjectRoot
The repository root directory path.

.PARAMETER ModuleName
The name of the module to generate help for.

.PARAMETER Culture
The culture or locale the help is to be generated in/for.
#>
function New-PSPackageProjectHelpStub
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ProjectRoot,

        [Parameter(Mandatory)]
        [string]
        $ModuleName,

        [Parameter()]
        [cultureinfo]
        $Culture = [cultureinfo]::CurrentCulture
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    $helpResourcePath = GetHelpPath -ProjectRoot $ProjectRoot -Culture $Culture

    New-Item -Path $helpResourcePath -ItemType Directory -ErrorAction Stop

    New-MarkdownAboutHelp -OutputFolder $helpResourcePath -AboutName $ModuleName
}

<#
.SYNOPSIS
Create or update cmdlet help stubs markdown files.

.DESCRIPTION
Creates or updates the cmdlet help resource files
for the given module.
The generated help will be stubs, requiring regions with {{ }}
to be filled in.

.PARAMETER ProjectRoot
The path to the repository root of the module.

.PARAMETER ModuleName
The name of the module to generate cmdlet help for.

.PARAMETER Culture
The culture in which cmdlet help should be created.
#>
function Add-PSPackageProjectCmdletHelp
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ProjectRoot,

        [Parameter(Mandatory)]
        [string]
        $ModuleName,

        [Parameter()]
        [cultureinfo]
        $Culture
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    $helpResourcePath = GetHelpPath -ProjectRoot $ProjectRoot -Culture $Culture

    RunProjectBuild -ProjectRoot $ProjectRoot

    $outModulePath = GetOutputModulePath -ProjectRoot $ProjectRoot -ModuleName $ModuleName

    if (-not (HasCmdletHelp -HelpResourcePath $helpResourcePath))
    {
        New-Item -Path $helpResourcePath -ItemType Directory -ErrorAction Ignore
        RunPwshCommandInSubprocess -Command "Import-Module '$outModulePath'; New-MarkdownHelp -Module $ModuleName -OutputFolder '$helpResourcePath'"
        return
    }

    RunPwshCommandInSubprocess -Command "Import-Module '$outModulePath'; Update-MarkdownHelp -Path '$helpResourcePath'"
}

<#
.SYNOPSIS
Assembles help files into staging output.

.DESCRIPTION
Compiles markdown help resources into
PowerShell external help files and places
them into the staging location.

.PARAMETER ProjectRoot
The path to the project repository root.

.PARAMETER ModuleName
The name of the module to publish help for.

.PARAMETER Culture
The locale or culture the help is written for.
#>
function Export-PSPackageProjectHelp
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ProjectRoot,

        [Parameter(Mandatory)]
        [string]
        $ModuleName,

        [Parameter()]
        [cultureinfo]
        $Culture = [cultureinfo]::CurrentCulture
    )

    $cultureName = $Culture.Name

    $helpResourcePath = GetHelpPath -ProjectRoot $ProjectRoot -Culture $Culture

    $outModulePath = GetOutputModulePath -ProjectRoot $ProjectRoot -ModuleName $ModuleName

    New-ExternalHelp -Path $helpResourcePath -OutputPath "$outModulePath/$cultureName" -Force
}

function Invoke-PSPackageProjectBuild
{
    param(
        [Parameter()]
        [ScriptBlock]
        $BuildScript
    )

    Write-Verbose -Verbose "Invoking build script"

    $BuildScript.Invoke()

    Write-Verbose -Verbose "Finished invoking build script"
}

#endregion Public commands

