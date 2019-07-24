# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

#region Private implementation functions

function Join-Path2 {
    param(
        [Parameter(Mandatory)]
        [string[]] $Path,

        [Parameter(Mandatory)]
        [string] $ChildPath,

        [Parameter(Mandatory)]
        [string[]] $AdditionalChildPath
    )

    $paths = [System.Collections.ArrayList]::new()

    $Path | ForEach-Object { $null = $paths.Add($_) }
    $null = $paths.Add($ChildPath)
    $AdditionalChildPath | ForEach-Object { $null = $paths.Add($_) }

    [System.IO.Path]::Join($paths)
}

function RunPwshCommandInSubprocess {
    param(
        [string]
        $Command
    )

    if (-not $script:pwshPath) {
        $script:pwshPath = (Get-Process -Id $PID).Path
    }

    & $script:pwshPath -NoProfile -NoLogo -Command $Command
}

function RunProjectBuild {
    param(
        [string]
        $ProjectRoot
    )

    & "$ProjectRoot/build.ps1" -Clean
}

function GetHelpPath {
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

function GetOutputModulePath {
    param(
        [string]
        $ProjectRoot,

        [string]
        $ModuleName
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    return "$ProjectRoot/out/$ModuleName"
}

function HasCmdletHelp {
    param(
        [string]
        $HelpResourcePath
    )

    if (-not (Test-Path -Path $HelpResourcePath)) {
        return $false
    }

    $files = Get-ChildItem -Path $HelpResourcePath -ErrorAction Ignore |
    Where-Object Name -Like '*.md' |
    Where-Object Name -NotLike 'about_*'

    return $files.Count -gt 0
}

function Initialize-CIYml {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $boilerplateCIYml = Join-Path2 -Path $PSScriptRoot -ChildPath 'yml' -AdditionalChildPath 'ci.yml'
    Copy-Item $boilerplateCIYml -Destination $Path

    $boilerplateTestYml = Join-Path2 -Path $PSScriptRoot -ChildPath 'yml' -AdditionalChildPath 'test.yml'
    Copy-Item $boilerplateTestYml -Destination $Path
}

function Show-Failure {
    param ( $testResults, [switch]$throw )
    $testFailures = $testResults | Where-Object { $_.Result -eq "Failure" }
    if ( $testFailures ) {
        $testFailures | Foreach-Object { Write-Error ("TEST FAILURE: " + $_.Name) }
        if ( $throw ) {
            throw ("{0} Failures" -f $testFailures.Count)
        }
        return $true
    }
    return $false
}

function Invoke-FunctionalValidation {
    param ( $testPath, $tags = "*" )
    try {
        Push-Location $testPath
        Invoke-Pester -Path . -tags $tags
    }
    finally {
        Pop-Location
    }
}

function Invoke-StaticValidation {
    param ( $stagingDirectory, $StaticValidators = @("BinSkim", "ScriptAnalyzer" ) )
    $fault = $false
    foreach ( $validator in $StaticValidators ) {
        $resultFile = & "Invoke-${validator}" -Location $stagingDirectory
        if ( Show-Failures -testResult $resultFile ) {
            $fault = $true
        }
    }
    if ($fault) {
        throw "Static Validation Errors"
    }
}

function Invoke-ScriptAnalyzer {
    try {
        Push-Location
        $results = Invoke-ScriptAnalyzer . | Where-Object { $_.Severity -match "Error" }
        if ( $results ) {
            foreach ($result in $results ) {
                $formattedResult = $result | Out-String
                Write-Error $formattedResult
            }
            throw "Script Analyzer failure"
        }
    }
    finally {
        Pop-Location
    }
}

function Test-Result
{

}

#endregion Private implementation functions

#region Public commands

function Invoke-PSPackageProjectTest {
    param(
        [Parameter()]
        [ValidateSet("Functional", "StaticAnalysis")]
        [string]
        $Type
    )

    END {
        if ( $type -contains "Functional" ) {
            # this will return a path to the results
            $resultFile = Invoke-FunctionalValidation -testPath $testPath
            $testResults = Test-Result -path $resultFile
            ##$null = Show-Failures $testResults
        }

        if ( $type -contains "Static" ) {
            Invoke-StaticValidation
        }
    }
}

function Invoke-BinSkim
{
    [CmdletBinding(DefaultParameterSetName='default')]
    param(
        [Parameter(ParameterSetName='byPath',Mandatory)]
        [string]
        $Location,
        [Parameter(ParameterSetName='byPath')]
        [string]
        $Filter = '*'
    )

    $sourceName = 'Nuget'
    Register-PackageSource -ProviderName NuGet -Name $sourceName -Location https://api.nuget.org/v3/index.json -erroraction ignore
    $packageName = 'microsoft.codeanalysis.binskim'
    $packageLocation = Join-Path -Path ([System.io.path]::GetTempPath()) -ChildPath 'pspackageproject-packages'
    Write-Verbose "Finding binskim..." -Verbose
    $packageInfo = Find-Package -Name $packageName -Source $sourceName
    if($IsLinux)
    {
        $binaryName ='BinSkim'
        $rid = 'linux-x64'
    }
    elseif($IsWindows -ne $false)
    {
        $binaryName ='BinSkim.exe'
        if([Environment]::Is64BitOperatingSystem)
        {
            $rid = 'win-x64'
        }
        else
        {
            $rid = 'win-x86'
        }
    }
    else {
        Write-Warning "unsupported platform"
        return
    }

    $dirName = $packageInfo.Name + '.' + $packageInfo.Version
    $toolLocation = Join-Path -Path $packageLocation -ChildPath $dirName -AdditionalChildPath 'tools', 'netcoreapp2.0', $rid, $binaryName
    if(!(test-path -path $toolLocation))
    {
        Write-Verbose "Installing binskim..." -Verbose
        $packageInfo | Install-Package -Destination $packageLocation -Force
    }

    if($IsLinux)
    {
        chmod a+x $toolLocation
    }

    if($Location)
    {
        $resolvedPath = (Resolve-Path -Path $Location).ProviderPath
        $toAnalyze = Join-Path -Path $resolvedPath -ChildPath $Filter
    }
    else
    {
        $toAnalyze = Join-Path -Path $packageLocation -ChildPath $dirName -AdditionalChildPath 'tools', 'netcoreapp2.0', $rid, '*'
    }

    $outputPath =  Join-Path -Path ([System.io.path]::GetTempPath()) -ChildPath 'pspackageproject-results.json'
    Write-Verbose "Running binskim..." -Verbose
    & $toolLocation analyze $toAnalyze --output $outputPath --pretty-print  > binskim.log 2>&1

    $testsPath = Join-Path -Path $PSScriptRoot -ChildPath 'tasks' -AdditionalChildPath 'BinSkim', 'binskim.tests.ps1'

    Write-Verbose "Generating test results..." -Verbose
    Invoke-Pester -Script $testsPath -OutputFile ./binskim-results.xml -OutputFormat NUnitXml
    $PowerShellName  = switch($PSVersionTable.PSEdition) {
            'Core' { 'PowerShell Core'}
            'Desktop' { 'Windows PowerShell' }
        }

    Publish-AzDevOpsArtifact -Path ./binskim-results.xml -Title "BinSkim $env:AGENT_OS - $PowerShellName Results" -Type NUnit
}

function Publish-AzDevOpsArtifact
{
    param(
        [parameter(Mandatory)]
        [string]
        $Path,
        [parameter(Mandatory)]
        [string]
        $Title,
        [string]
        $Type = 'NUnit'
    )

    $artifactPath = (Resolve-Path $Path).ProviderPath

    # Just do nothing if we are not in AzDevOps
    if($env:TF_BUILD)
    {
        Write-Host "##vso[results.publish type=$Type;mergeResults=true;runTitle=$Title;publishRunAttachments=true;resultFiles=$artifactPath;failTaskOnFailedTests=true;]"
    }
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
function New-PSPackageProjectHelpStub {
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
function Add-PSPackageProjectCmdletHelp {
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

    if (-not (HasCmdletHelp -HelpResourcePath $helpResourcePath)) {
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
function Export-PSPackageProjectHelp {
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

function Invoke-PSPackageProjectBuild {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ScriptBlock]
        $BuildScript
    )

    Write-Verbose -Verbose "Invoking build script"

    $BuildScript.Invoke()

    Write-Verbose -Verbose "Finished invoking build script"
}

function Initialize-PSPackageProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ModuleName,
        [string]$ModuleBase = ".",
        [switch]$Force
    )

    if ( [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($ModuleBase) ) {
        throw "Modulebase '${ModuleBase}' contains wildcards"
    }

    $ModuleRoot = (Resolve-Path $ModuleBase -ea SilentlyContinue ).Path
    if ( $ModuleRoot -and ! $force ) {
        throw "'${ModuleRule}' already exists, use -Force to overwrite"
    }

    if ( ! $ModuleRoot ) {
        $ModuleRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModuleBase)
    }
    $null = New-Item -ItemType Directory -Path $ModuleRoot
    $ModuleInfo = @{
        ModuleName = $ModuleName
        ModuleRoot = $ModuleRoot
    }

    # Create the help directory
    # and populate a couple of files
    $currentCulture = [System.Globalization.CultureInfo]::CurrentCulture.Name
    $ModuleInfo['Culture'] = $currentCulture
    $helpBase = [System.IO.Path]::Join($ModuleRoot, "Help", $currentCulture)
    $aboutMod = [System.IO.Path]::Join($helpBase, "${ModuleName}.md")
    $null = New-Item -Type Directory $helpBase -Force
    "# About Module $ModuleName" | Out-File -FilePath $aboutMod

    # Create the scaffold for .psd1 and .psm1
    $moduleSourceBase = [System.IO.Path]::Join($ModuleRoot, "src")
    $null = New-Item -ItemType Directory -Path $moduleSourceBase
    $moduleFileWithoutExtension = [system.io.path]::join($moduleSourceBase, ${ModuleName})
    New-ModuleManifest -Path "${moduleFileWithoutExtension}.psd1"
    $null = New-Item -Type File "${moduleFileWithoutExtension}.psm1"

    # Create a directory for cs sources and create a classlib csproj file with
    # System.Management.Automation as a package reference
    $moduleCodeBase = [System.IO.Path]::Join($moduleSourceBase, "code")
    $null = New-Item -ItemType Directory -Path $moduleCodeBase
    try {
        Push-Location $moduleCodeBase
        $output = dotnet new classlib -f netstandard2.0 --no-restore --force
        $output += dotnet add package PowerShellStandard.Library
        Move-Item code.csproj "${ModuleName}.csproj"
        @"
using System;
using System.Management.Automation;

namespace ${ModuleName}
{
    [Cmdlet("verb","noun")]
    public class Cmdlet1 : PSCmdlet
    {
        [Parameter(Mandatory=true,Position=0)]
        public string Name {get;set;}

        protected override void ProcessRecord()
        {
            WriteObject(Name);
        }
    }
}
"@ > Class1.cs
    }
    finally {
        Pop-Location
    }

    # make test folder and create a test template
    $null = New-Item -ItemType Directory -Path "${moduleRoot}/Test"

    # make CI ymls
    Initialize-CIYml -Path ${moduleRoot}
}

#endregion Public commands

