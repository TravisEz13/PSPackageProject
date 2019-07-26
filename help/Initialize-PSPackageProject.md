---
external help file: PSPackageProject-help.xml
Module Name: PSPackageProject
online version:
schema: 2.0.0
---

# Initialize-PSPackageProject

## SYNOPSIS
Scaffolds a new PowerShell project.

## SYNTAX

```
Initialize-PSPackageProject [-ModuleName] <String> [-ModuleBase <String>] [-Force] [<CommonParameters>]
```

## DESCRIPTION
Creates a new PowerShell project scaffold with all required components:

- A module manifest
- A script module file
- A new C# project
- Azure DevOps CI YAML templates, with
    - Static analysis CI tasks:
        - PSScriptAnalyzer checks
        - BinSkim binary analysis
- An empty Pester test suite
- A `build.ps1` build script for building and testing
- About help templates for the module

## EXAMPLES

### Example 1
```powershell
PS C:\> Initialize-PSPackageProject -ModuleName 'MyModule'
```

Creates a new PowerShell project for the module `MyModule` in the current directory.

Sets up the following structure:

```text
$PWD
  +-- src/
  |     +-- MyModule.psd1
  |     +-- MyModule.psm1
  |     +-- code/
  |            +-- ModuleName.csproj
  |            +-- Class1.cs
  |
  +-- help/
  |      +-- en-US/
  |              +-- about_MyModule.md
  |
  +--test/
  |     + MyModule.Tests.ps1
  |
  +-- out/ # Output directory where built module will go
  |
  +-- .ci/
  |     +-- ci.yml
  |     +-- test.yml
  |
  +-- .gitignore
```

## PARAMETERS

### -Force
Will overwrite the contents of the given ModuleBase directory if there are any.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleBase
The root directory of the project to create.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleName
The name of the module that the project builds.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object
## NOTES

## RELATED LINKS
