# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

param (
    [Parameter(ParameterSetName="build")]
    [switch]
    $Clean,

    [Parameter(ParameterSetName="build")]
    [switch]
    $Build,

    [Parameter(ParameterSetName="build")]
    [switch]
    $Test,

    [Parameter(ParameterSetName="help")]
    [switch]
    $UpdateHelp
)

$config = Get-Content -Path (Join-Path $PSScriptRoot 'pspackageproject.json') | ConvertFrom-Json

$script:ModuleName = $config.ModuleName
$script:SrcPath = $config.SourceRootPath
$script:OutDirectory = $config.BuildOutputPath

$script:ModuleRoot = Join-Path $PSScriptRoot $SrcPath
$script:Culture = $config.Culture

<#
.DESCRIPTION
Implement build and packaging of the package and place the output $OutDirectory/$ModuleName
#>
function DoBuild
{
    Write-Verbose -Verbose "Starting DoBuild"

    # copy psm1 and psd1 files
    copy-item "${SrcPath}/${ModuleName}.psd1" "${OutDirectory}/${ModuleName}"
    copy-item "${SrcPath}/${ModuleName}.psm1" "${OutDirectory}/${ModuleName}"
    # copy format files here
    #

    # copy help
    copy-item -Recurse "${SrcPath}/Help/${Culture}" "${OutDirectory}/${ModuleName}"

    # 
    try {
        Push-Location "${SrcPath}/code"
        $result = dotnet publish
        copy-item "${SrcPath}/src/code/bin/Debug/netstandard2.0/publish/${ModuleName}.dll" "${OutDirectory}/${ModuleName}"
    }
    catch {
        $result | ForEach-Object { Write-Warning $_ }
        Write-Error "dotnet build failed"
    }
    finally {
        Pop-Location
    }

    ## Add build and packaging here
    Write-Verbose -Verbose "Ending DoBuild"
}

Install-Module PSPackageProject

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
