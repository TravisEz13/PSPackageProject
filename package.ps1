param(
    [parameter(Mandatory)]
    $Version,
    $Folder = $env:SIGNED_OUTPUT_PATH,
    $OutputDirectory = ([System.IO.Path]::GetTempPath())
)

$nuspec = @'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd">
  <metadata>
    <id>PSPackageProject</id>
    <version>{0}</version>
    <authors>Microsoft Corporation</authors>
    <owners>Microsoft Corporation</owners>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <licenseUrl>https://github.com/TravisEz13/PsAzDevOpsExt/blob/master/LICENSE</licenseUrl>
    <projectUrl>https://github.com/TravisEz13/PsAzDevOpsExt</projectUrl>
    <description>Module to help with building and publishing PowerShell packages</description>
    <releaseNotes></releaseNotes>
    <copyright>(c) Microsoft Corporation. All rights reserved</copyright>
    <tags>PSModule PSIncludes_Function PSFunction_Initialize-PSPackageProject PSFunction_Invoke-PSPackageProjectTest PSFunction_Add-PSPackageProjectCmdletHelp PSFunction_Export-PSPackageProjectHelp PSFunction_New-PSPackageProjectHelp PSFunction_Invoke-PSPackageProjectBuild PSFunction_Invoke-PSPackageProjectPublish PSFunction_Get-PSPackageProjectConfiguration PSCommand_Initialize-PSPackageProject PSCommand_Invoke-PSPackageProjectTest PSCommand_Add-PSPackageProjectCmdletHelp PSCommand_Export-PSPackageProjectHelp PSCommand_New-PSPackageProjectHelp PSCommand_Invoke-PSPackageProjectBuild PSCommand_Invoke-PSPackageProjectPublish PSCommand_Get-PSPackageProjectConfiguration</tags>
    <dependencies>
      <dependency id="platyPS" version="0.14.0" />
      <dependency id="Pester" version="4.8.1" />
      <dependency id="PSScriptAnalyzer" version="1.18.0" />
    </dependencies>
  </metadata>
  <files>
    <file src="**\*.*" target="" />
  </files>
</package>
'@

$actualNuspec = $nuspec -f $Version

$nuspecPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "test.nuspec"

$actualNuspec | Out-File -FilePath $nuspecPath -Encoding utf8NoBOM

Push-Location $Folder
try {
    nuget pack $nuspecPath -NoPackageAnalysis -OutputDirectory $OutputDirectory
}
finally {
    Pop-Location
}
