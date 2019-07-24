# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

param(
    [switch]
    $Clean,

    [switch]
    $Build
)

$config = Get-PSPackageProjectConfiguration -ProjectRoot $PSScriptRoot

$script:ModuleName = $config.ModuleName
$script:SrcPath = $config.SourcePath
$script:OutDirectory = $config.BuildOutputPath

$script:ModuleRoot = Join-Path $PSScriptRoot $SrcPath

<#
.DESCRIPTION
Implement build and packaging of the package and place the output $OutDirectory/$ModuleName
#>
function DoBuild
{
    Write-Verbose -Verbose "Starting DoBuild"
    Get-ChildItem -Path $script:ModuleRoot -Filter "*.ps*1" |
        ForEach-Object { Copy-Item -Path $_.FullName -Destination $script:OutModule -Verbose }
    Copy-Item -Path (Join-Path $script:ModuleRoot 'yml') -Recurse $script:OutModule -Force
    Copy-Item -Path (Join-Path $script:SrcPath 'build_for_init.ps1') -Destination $script:OutModule

    Write-Verbose -Verbose "Ending DoBuild"
}

#region Special casing for PSPackageProject CI system
$PSPackageProjectModule = [System.IO.Path]::Combine($PSScriptRoot, $SrcPath, "$ModuleName.psd1")
Import-Module $PSPackageProjectModule -Force
#endregion

if ($Clean -and (Test-Path $OutDirectory))
{
    Remove-Item -Force -Recurse $OutDirectory -ErrorAction Stop -Verbose
}

if (-not (Test-Path $OutDirectory))
{
    $script:OutModule = New-Item -ItemType Directory -Path (Join-Path $OutDirectory $ModuleName)
}
else
{
    $script:OutModule = Join-Path $OutDirectory $ModuleName
}

if ($Build.IsPresent)
{
    $sb = (Get-Item Function:DoBuild).ScriptBlock
    Invoke-PSPackageProjectBuild -BuildScript $sb
}
