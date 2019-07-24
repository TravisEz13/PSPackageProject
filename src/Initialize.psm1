# create the layout
# and populate a few files
function Initialize-ModulePackage
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ModuleName,
        [string]$ModuleBase = ".",
        [switch]$force
    )

    if ( [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($ModuleBase) ) {
        throw "Modulebase '${ModuleBase}' contains wildcards"
    }


    $ModuleRoot = (Resolve-Path $ModuleBase -ea SilentlyContinue ).Path
    if ( $ModuleRoot -and ! $force ) {
        throw "'${ModuleRule}' already exists, use -force to overwrite"
    }

    if ( ! $ModuleRoot ) {
        $ModuleRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModuleBase)
    }
    $null = New-Item -ItemType Directory -PAth $ModuleRoot
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
    "# About Module $ModuleName" |Out-File -FilePath $aboutMod

    # Create the scaffold for .psd1 and .psm1
    $moduleSourceBase = [System.IO.Path]::Join($ModuleRoot, "src")
    $null = New-Item -ItemType Directory -Path $moduleSourceBase
    $moduleFileWithoutExtension = [system.io.path]::join($moduleSourceBase, ${ModuleName})
    New-ModuleManifest -Path "${moduleFileWithoutExtension}.psd1"
    $null = New-Item -Type File "${moduleFileWithoutExtension}.psm1"

    # Create a directory for cs sources and create a classlib csproj file with
    # System.Management.Automation as a package reference
    $moduleCodeBase = [System.IO.Path]::Join($moduleSourceBase,"code")
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
# make templates folder


}

function Invoke-PSPackageProjectTest
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $stagingDirectory = "out",
        [Parameter()]
        [ValidateSet("Functional","Static")]
        [string[]]
        $Type = @("Functional","Static")
    )

    END {
        if ( $type -contains "Functional" ) {
            # this will return a path to the results
            $resultFile = Invoke-FunctionalValidation -testPath $testPath
            $testResults = Test-Result -path $resultFile
            $null = Show-Failures $testResults
        }

        if ( $type -contains "Static" ) {
            Invoke-StaticValidation
        }

    }
}

function Show-Failure
{
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

# Invoke the various tests, if you want to add more test

function Invoke-FunctionalValidation
{
    param ( $testPath, $tags = "*" )
    try {
        Push-Location $testPath
        Invoke-Pester -Path . -tags $tags
    }
    finally {
        Pop-Location
    }
}

function Invoke-StaticValidation
{
    param ( $stagingDirectory, $StaticValidators = @("BinSkim","ScriptAnalyzer" ) )
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
function Invoke-BinSkim
{
    # for the moment, just return
}

function Invoke-ScriptAnalyzer
{
    try {
        Push-Location
        $results = Invoke-ScriptAnalyzer . | Where-Object {$_.Severity -match "Error"}
        if ( $results ) {
            foreach ($result in $results ) {
                $formattedResult = $result | Out-String
                Write-Error $formattedResult
            }
            throw "Script Analyzer failure"
        }
    }
    finally
    {
        Pop-Location
    }
}