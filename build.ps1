# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

param(
    [switch]
    $Clean,

    [switch]
    $Build,

    [Parameter()]
    [string]
    $OutDirectory = "$PSScriptRoot/out"
)

$script:ModuleName = "PSPackageProject"
$script:SrcPath = "$PSScriptRoot/src"

$script:CopyAssets = @{
    "PSPackageProject.psd1" = "PSPackageProject.psd1"
    "PSPackageProject.psm1" = "PSPackageProject.psm1"
}

if ($Clean -and (Test-Path $OutDirectory))
{
    Remove-Item -Force -Recurse $OutDirectory -ErrorAction Stop
}

$outModule = New-Item -ItemType Directory -Path "$OutDirectory/$script:ModuleName"
foreach ($assetSrcPath in $script:CopyAssets.get_Keys())
{
    $destinationPath = Join-Path $outModule $script:CopyAssets[$assetSrcPath]
    Copy-Item -LiteralPath "$script:SrcPath/$assetSrcPath" $destinationPath
}
