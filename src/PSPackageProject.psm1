# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

#region Private implementation functions

function GetPowerShellName {
    switch ($PSVersionTable.PSEdition) {
        'Core' {
            return 'PowerShell Core'
        }

        default {
            return 'Windows PowerShell'
        }
    }
}

function Test-ConfigFile {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if ($Path.EndsWith('pspackageproject.json') -and (Test-Path $Path -PathType Leaf)) {
        return $true
    }
}

function SearchConfigFile {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $startPath = $Path

    do {
        $configPath = Join-Path $startPath 'pspackageproject.json'

        if (-not (Test-Path $configPath)) {
            $startPath = Split-Path $startPath
        }
        else {
            return $configPath
        }
    } while ($newPath -ne '')
}

function Join-Path2 {
    param(
        [Parameter(Mandatory)]
        [string[]] $Path,

        [Parameter(Mandatory)]
        [string] $ChildPath,

        [string[]] $AdditionalChildPath
    )

    $paths = [System.Collections.ArrayList]::new()

    $Path | ForEach-Object { $null = $paths.Add($_) }
    $null = $paths.Add($ChildPath)
    $AdditionalChildPath | ForEach-Object { $null = $paths.Add($_) }

    [System.IO.Path]::Combine($paths)
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

    & "$ProjectRoot/build.ps1" -Clean -Build
}

function GetHelpPath {
    param(
        [cultureinfo]
        $Culture,

        [string]
        $ProjectRoot
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    $config = Get-PSPackageProjectConfiguration

    $cultureName = $Culture.Name

    return (Join-Path2 $ProjectRoot $config.HelpPath $cultureName)
}

function GetOutputModulePath {
    param(
        [string]
        $ProjectRoot,

        [string]
        $ModuleName
    )

    $ProjectRoot = Resolve-Path -Path $ProjectRoot

    $config = Get-PSPackageProjectConfiguration

    return (Join-Path2 $ProjectRoot $config.BuildOutputPath $ModuleName)
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

    $boilerplateCIYml = Join-Path2 -Path $PSScriptRoot -ChildPath 'yml' -AdditionalChildPath 'ci_for_init.yml'
    $destYmlPath = New-Item (Join-Path -Path $Path -ChildPath '.ci') -ItemType Directory
    Copy-Item $boilerplateCIYml -Destination (Join-Path $destYmlPath -ChildPath 'ci.yml') -Force

    $boilerplateTestYml = Join-Path2 -Path $PSScriptRoot -ChildPath 'yml' -AdditionalChildPath 'test_for_init.yml'
    Copy-Item $boilerplateTestYml -Destination (Join-Path $destYmlPath -ChildPath 'test.yml') -Force
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
    $config = Get-PSPackageProjectConfiguration
    try {

        $testResultFile = "result.pester.xml"
        $modStage = "./{0}/{1}" -f $config.BuildOutputPath,$config.ModuleName
        $command = "import-module ${modStage}; Set-Location $testPath; Invoke-Pester -Path . -OutputFile ${testResultFile} -tags '$tags'"
        $output = RunPwshCommandInSubprocess -command $command | Foreach-Object { Write-Verbose -Verbose $_ }
        return (Join-Path ${testPath} "$testResult")
    }
    catch {
        $output | Foreach-Object { Write-Warning "$_" }
        Write-Error "Error invoking tests"
    }
}

function Invoke-StaticValidation {
    param ( $stagingDirectory, $StaticValidators = @("BinSkim", "ScriptAnalyzer" ) )
    $fault = $false

    $config = Get-PSPackageProjectConfiguration

    foreach ( $validator in $StaticValidators ) {
        Write-Verbose "Running Invoke-${validator}" -Verbose

        $resultFile = & "Invoke-${validator}" -Location $config.BuildOutputPath
        if ( Show-Failure -testResult $resultFile ) {
            $fault = $true
        }
    }
    if ($fault) {
        throw "Static Validation Errors"
    }
}

function RunScriptAnalysis {
    param(
        [Parameter()]
        [string]
        $ProjectRoot,

        [Parameter()]
        [string]
        $ModuleName
    )

    try {
        Push-Location
        $pssaParams = @{
            Severity = 'Warning', 'ParseError'
            Path     = GetOutputModulePath -ProjectRoot $ProjectRoot -ModuleName $ModuleName
            Recurse  = $true
        }
        $results = Invoke-ScriptAnalyzer @pssaParams
        if ( $results ) {
            foreach ($result in $results ) {
                $formattedResult = $result | Out-String
                Write-Error $formattedResult
            }

            if ($env:TF_BUILD) {
                $xmlPath = ConvertPssaDiagnosticsToNUnit -Diagnostic $results
                $powershellName = GetPowerShellName
                Publish-AzDevOpsArtifact -Path $xmlPath -Title "PSScriptAnalyzer $env:AGENT_OS - $powershellName Results" -Type NUnit
            }

            throw "Script Analyzer failure"
        }
    }
    finally {
        Pop-Location
    }
}

function Test-Result {
}

function ConvertPssaDiagnosticsToNUnit {
    param(
        [Parameter(ValueFromPipeline)]
        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
        $Diagnostic
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.Append('Describe "PSScriptAnalyzer Diagnostics" {')
    foreach ($d in $Diagnostic) {
        $severity = $d.Severity
        $ruleName = $d.RuleName
        $message = $d.Message
        $description = "[$severity] ${ruleName}: $message"
        $null = $sb.Append("It '$description' { throw 'FAIL' }")
    }
    $null = $sb.Append('}')

    $testPath = Join-Path ([System.IO.Path]::GetTempPath()) "pssa.tests.ps1"
    $xmlPath = Join-Path ([System.IO.Path]::GetTempPath()) "pssa.xml"

    try {
        Set-Content -Path $testPath -Value $sb.ToString()
        Invoke-Pester -Script $testPath -OutputFormat NUnitXml -OutputFile $xmlPath
    }
    finally {
        Remove-Item -Path $testPath -Force
    }

    return $xmlPath
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
function Initialize-PSPackageProjectHelp {
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

    $null = New-Item -Path $helpResourcePath -ItemType Directory -ErrorAction Stop

    New-MarkdownAboutHelp -OutputFolder $helpResourcePath -AboutName $ModuleName
}

#endregion Private implementation functions

#region Public commands

function Invoke-PSPackageProjectTest {
    param(
        [Parameter()]
        [ValidateSet("Functional", "StaticAnalysis")]
        [string[]]
        $Type
    )

    END {
        $config = Get-PSPackageProjectConfiguration
        if ($Type -contains "Functional" ) {
            # this will return a path to the results
            $resultFile = Invoke-FunctionalValidation -testPath $config.TestPath
            $testResults = Test-Result -path $resultFile
            $null = Show-Failure $testResults
        }

        if ($Type -contains "StaticAnalysis" ) {
            Invoke-StaticValidation -Staging
        }
    }
}

function Invoke-BinSkim {
    [CmdletBinding(DefaultParameterSetName = 'default')]
    param(
        [Parameter(ParameterSetName = 'byPath', Mandatory)]
        [string]
        $Location,
        [Parameter(ParameterSetName = 'byPath')]
        [string]
        $Filter = '*'
    )

    $sourceName = 'Nuget'
    Register-PackageSource -ProviderName NuGet -Name $sourceName -Location https://api.nuget.org/v3/index.json -erroraction ignore
    $packageName = 'microsoft.codeanalysis.binskim'
    $packageLocation = Join-Path2 -Path ([System.io.path]::GetTempPath()) -ChildPath 'pspackageproject-packages'
    Write-Verbose "Finding binskim..." -Verbose
    $packageInfo = Find-Package -Name $packageName -Source $sourceName
    if ($IsLinux) {
        $binaryName = 'BinSkim'
        $rid = 'linux-x64'
    }
    elseif ($IsWindows -ne $false) {
        $binaryName = 'BinSkim.exe'
        if ([Environment]::Is64BitOperatingSystem) {
            $rid = 'win-x64'
        }
        else {
            $rid = 'win-x86'
        }
    }
    else {
        Write-Warning "unsupported platform"
        return
    }

    $dirName = $packageInfo.Name + '.' + $packageInfo.Version
    $toolLocation = Join-Path2 -Path $packageLocation -ChildPath $dirName -AdditionalChildPath 'tools', 'netcoreapp2.0', $rid, $binaryName
    if (!(test-path -path $toolLocation)) {
        Write-Verbose "Installing binskim..." -Verbose
        $packageInfo | Install-Package -Destination $packageLocation -Force
    }

    if ($IsLinux) {
        chmod a+x $toolLocation
    }

    if ($Location) {
        $resolvedPath = (Resolve-Path -Path $Location).ProviderPath
        $toAnalyze = Join-Path2 -Path $resolvedPath -ChildPath $Filter
    }
    else {
        $toAnalyze = Join-Path2 -Path $packageLocation -ChildPath $dirName -AdditionalChildPath 'tools', 'netcoreapp2.0', $rid, '*'
    }

    $outputPath = Join-Path2 -Path ([System.io.path]::GetTempPath()) -ChildPath 'pspackageproject-results.json'
    Write-Verbose "Running binskim..." -Verbose
    & $toolLocation analyze $toAnalyze --output $outputPath --pretty-print  > binskim.log 2>&1

    $testsPath = Join-Path2 -Path $PSScriptRoot -ChildPath 'tasks' -AdditionalChildPath 'BinSkim', 'binskim.tests.ps1'

    Write-Verbose "Generating test results..." -Verbose
    Invoke-Pester -Script $testsPath -OutputFile ./binskim-results.xml -OutputFormat NUnitXml
    $PowerShellName = GetPowerShellName

    Publish-AzDevOpsTestResult -Path ./binskim-results.xml -Title "BinSkim $env:AGENT_OS - $PowerShellName Results" -Type NUnit
    return ./binskim-results.xml
}

function Publish-AzDevOpsTestResult {
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
    if ($env:TF_BUILD) {
        Write-Host "##vso[results.publish type=$Type;mergeResults=true;runTitle=$Title;publishRunAttachments=true;resultFiles=$artifactPath;failTaskOnFailedTests=true;]"
    }
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

    New-PSPackageProjectPackage

    Write-Verbose -Verbose "Finished invoking build script"
}

function New-PSPackageProjectPackage
{
    Write-Verbose -Message "Starting New-PSPackageProjectPackage" -Verbose
    $ErrorActionPreference = 'Stop'
    $config = Get-PSPackageProjectConfiguration
    $modulePath = Join-Path2 -Path $config.BuildOutputPath -ChildPath $config.ModuleName
    $sourceName = 'pspackageproject-local-repo'
    $packageLocation = Join-Path2 -Path ([System.io.path]::GetTempPath()) -ChildPath $sourceName
    $modulesLocation = Join-Path2 -Path $packageLocation -ChildPath 'modules'

    if (Test-Path $modulesLocation) {
        Remove-Item $modulesLocation -Recurse -Force -ErrorAction Ignore
    }

    $null = New-Item -Path $modulesLocation -Force -ItemType Directory
    $scriptsLocation = $modulesLocation

    Write-Verbose -Message "Starting dependency download" -Verbose

    # TODO : dynamically detect module dependecies and save them
    Save-Package2 -Name PlatyPs -Location $modulesLocation
    Save-Package2 -Name Pester -Location $modulesLocation
    Save-Package2 -Name PSScriptAnalyzer -Location $modulesLocation

    Write-Verbose -Message "Dependency download complete" -Verbose

    Register-PSRepository -Name $sourceName -SourceLocation $modulesLocation -PublishLocation $modulesLocation -ScriptSourceLocation $scriptsLocation -ScriptPublishLocation $scriptsLocation -erroraction Ignore
    Publish-Module -Path $modulePath -Repository $sourceName -NuGetApiKey 'fake' -Force

    Write-Verbose -Message "Local package published" -Verbose

    $nupkgPath = (Get-ChildItem -Path $modulesLocation -Filter "$($config.ModuleName)*.nupkg").FullName
    Publish-Artifact -Path $nupkgPath -Name nupkg

    Write-Verbose -Message "Starting New-PSPackageProjectPackage" -Verbose
}

# Wrapper to push artifact
function Publish-Artifact
{
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path -Path $_})]
        $Path,
        [string]
        $Name
    )

    if(!$Name)
    {
        $artifactName = [system.io.path]::GetFileName($Path)
    }
    else
    {
        $artifactName = $Name
    }

    if ($env:TF_BUILD) {
        # In Azure DevOps
        Write-Host "##vso[artifact.upload containerfolder=$artifactName;artifactname=$artifactName;]$Path"
    }
}

function Save-Package2
{
    param(
        [string]
        $Name,
        [String]
        $Location
    )

    $packageInfo = Find-Module -Name $Name -erroraction ignore -Repository PSGallery
    if($packageInfo)
    {
        $packagePath = Join-Path2 -Path $Location -ChildPath ($packageInfo.Name+'.'+$packageInfo.Version+'.nupkg')
        Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/$($packageInfo.Name)/$($packageInfo.Version)" -OutFile $packagePath
    }
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
        throw "'${ModuleRoot}' already exists, use -Force to overwrite"
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
    Initialize-PSPackageProjectHelp -ProjectRoot $ModuleRoot -ModuleName $ModuleName

    # Create the scaffold for .psd1 and .psm1
    $moduleSourceBase = Join-Path $ModuleRoot "src"
    $null = New-Item -ItemType Directory -Path $moduleSourceBase
    $moduleFileWithoutExtension = Join-Path $moduleSourceBase ${ModuleName}
    New-ModuleManifest -Path "${moduleFileWithoutExtension}.psd1" -CmdletsToExport "verb-noun" -RootModule "./${ModuleName}.dll"
    $null = New-Item -Type File "${moduleFileWithoutExtension}.psm1"

    # Create a directory for cs sources and create a classlib csproj file with
    # System.Management.Automation as a package reference
    $moduleCodeBase = Join-Path $moduleSourceBase "code"
    $null = New-Item -ItemType Directory -Path $moduleCodeBase
    try {
        Push-Location $moduleCodeBase
        $output = dotnet new classlib -f netstandard2.0 --no-restore --force
        $output += dotnet add package PowerShellStandard.Library --no-restore
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
    $testDir = Join-Path $moduleRoot 'test'
    $testTemplate = Join-Path $testDir "${moduleName}.Tests.ps1"
    $null = New-Item -ItemType Directory -Path "${testDir}"
    @"
Describe "Test ${moduleName}" -tags CI {
    BeforeAll {
    }
    BeforeEach {
    }
    AfterEach {
    }
    AfterAll {
    }
    It "This is the first test for ${moduleName}" {
        `$name = "Hello World"
        verb-noun -name `$name | Should -BeExactly `$name
    }
}
"@ | Out-File "${testTemplate}"

    # make CI ymls
    Initialize-CIYml -Path ${moduleRoot}

    # make build.ps1
    $boilerplateBuildScript = Join-Path -Path $PSScriptRoot -ChildPath 'build_for_init.ps1'
    Copy-Item $boilerplateBuildScript -Destination (Join-Path $ModuleRoot -ChildPath 'build.ps1') -Force

    # make pspackageproject.json
    $jsonPrj =
    @{
        SourcePath = "src"
        ModuleName = "${ModuleName}"
        TestPath = 'test'
        HelpPath = 'help'
        BuildOutputPath = 'out'
        Culture = [CultureInfo]::CurrentCulture.Name # This needs to be settable
    } | ConvertTo-Json

    if ($(${PSVersionTable}.PSEdition) -eq 'Desktop') {
        Write-Warning -Message "UTF-8 characters for module name are not supported in Windows PowerShell."
        $jsonPrj | Out-File (Join-Path ${moduleRoot} "pspackageproject.json") -Encoding ascii
    }
    else {
        $jsonPrj | Out-File (Join-Path ${moduleRoot} "pspackageproject.json") -Encoding utf8NoBOM
    }
}

function Get-PSPackageProjectConfiguration {
    param(
        [Parameter()]
        [string] $ConfigPath = "."
    )

    $resolvedPath = Resolve-Path $ConfigPath

    $foundConfigFilePath = if (Test-Path $resolvedPath -PathType Container) {
        SearchConfigFile -Path $resolvedPath
    }
    else {
        if (Test-ConfigFile -Path $resolvedPath) {
            $resolvedPath
        }
    }

    if (Test-Path $foundConfigFilePath) {
        $configObj = Get-Content -Path $foundConfigFilePath | ConvertFrom-Json

        # Populate with full paths

        $projectRoot = Split-Path $foundConfigFilePath

        $configObj.SourcePath = Join-Path $projectRoot -ChildPath $configObj.SourcePath
        $configObj.TestPath = Join-Path $projectRoot -ChildPath $configObj.TestPath
        $configObj.HelpPath = Join-Path $projectRoot -ChildPath $configObj.HelpPath
        $configObj.BuildOutputPath = Join-Path $projectRoot -ChildPath $configObj.BuildOutputPath

        $configObj
    }
    else {
        throw "'pspackageproject.json' not found at: $resolvePath or any or its parent"
    }
}

#endregion Public commands
