# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

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

function New-PSPackageProjectHelpStub
{
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

    $ProjectRoot = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($ProjectRoot)

    if (-not (Test-Path $ProjectRoot -PathType Container))
    {
        throw "Path '$ProjectRoot' is not a valid directory"
    }

    $cultureName = $Culture.Name

    $helpResourcePath = "$ProjectRoot/help/$cultureName"

    New-Item -Path $helpResourcePath -ItemType Directory -ErrorAction Stop

    New-MarkdownAboutHelp -OutputFolder $helpResourcePath -AboutName $ModuleName
}
