# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

param (
    [Parameter(ParameterSetName="build")]
    [switch]
    $Clean,

    [Parameter(ParameterSetName="build")]
    [switch]
    $Build,

    [Parameter(ParameterSetName="publish")]
    [switch]
    $Publish,

    [Parameter(ParameterSetName="publish")]
    [switch]
    $Signed,

    [Parameter(ParameterSetName="build")]
    [switch]
    $Test,

    [Parameter(ParameterSetName="build")]
    [string[]]
    [ValidateSet("Functional","StaticAnalysis")]
    $TestType = @("Functional"),

    [Parameter(ParameterSetName="help")]
    [switch]
    $UpdateHelp
)

$config = Get-Content -Path (Join-Path $PSScriptRoot 'pspackageproject.json') | ConvertFrom-Json

$script:ModuleName = $config.ModuleName
$script:SrcPath = $config.SourcePath
$script:OutDirectory = $config.BuildOutputPath
$script:SignedDirectory = $config.SignedOutputPath
$script:TestPath = $config.TestPath

$script:ModuleRoot = $PSScriptRoot
$script:Culture = $config.Culture
$script:HelpPath = $config.HelpPath

if ($env:TF_BUILD) {
    $vstsCommandString = "vso[task.setvariable variable=BUILD_OUTPUT_PATH]$(Join-Path $PSScriptRoot  -ChildPath $OutDirectory)"
    Write-Host "sending " + $vstsCommandString
    Write-Host "##$vstsCommandString"

    $vstsCommandString = "vso[task.setvariable variable=SIGNED_OUTPUT_PATH]$(Join-Path $PSScriptRoot  -ChildPath $SignedDirectory)"
    Write-Host "sending " + $vstsCommandString
    Write-Host "##$vstsCommandString"
}

<#
.DESCRIPTION
Implement build and packaging of the package and place the output $OutDirectory/$ModuleName
#>
function DoBuild
{
    Write-Verbose -Verbose -Message "Starting DoBuild"
    Get-ChildItem -Path $script:SrcPath -Filter "*.ps*1" |
        ForEach-Object { Copy-Item -Path $_.FullName -Destination $script:OutModule -Verbose }
    Copy-Item -Path (Join-Path $script:SrcPath 'yml') -Recurse $script:OutModule -Force -Verbose
    Copy-Item -Path (Join-Path $script:SrcPath 'build_for_init.ps1') -Destination $script:OutModule -Verbose
    Copy-Item -Path (Join-Path $script:SrcPath 'gitignore_for_init') -Destination $script:OutModule -Verbose
    Copy-Item -Path (Join-Path $script:SrcPath 'dobuild.ps1') -Destination $script:OutModule -Verbose
    Copy-Item -Path (Join-Path $script:SrcPath 'WHAT_TO_DO_NEXT.md') -Destination $script:OutModule -Verbose

    Write-Verbose -Verbose -Message "Ending DoBuild"
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
    Invoke-PSPackageProjectBuild -BuildScript $sb -SkipPublish
}

if ($Publish.IsPresent)
{
    Invoke-PSPackageProjectPublish -Signed:$Signed.IsPresent
}

if ( $Test.IsPresent ) {
    Invoke-PSPackageProjectTest -Type $TestType
}

if ($UpdateHelp.IsPresent) {
    Add-PSPackageProjectCmdletHelp -ProjectRoot $ModuleRoot -ModuleName $ModuleName -Culture $Culture
}
