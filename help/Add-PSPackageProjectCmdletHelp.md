---
external help file: PSPackageProject-help.xml
Module Name: PSPackageProject
online version:
schema: 2.0.0
---

# Add-PSPackageProjectCmdletHelp

## SYNOPSIS
Create or update cmdlet help stubs markdown files.

## SYNTAX

```
Add-PSPackageProjectCmdletHelp [-ProjectRoot] <String> [-ModuleName] <String> [[-Culture] <CultureInfo>]
 [<CommonParameters>]
```

## DESCRIPTION
Creates or updates the cmdlet help resource files
for the given module.
The generated help will be stubs, requiring regions with {{ }}
to be filled in.

## EXAMPLES

### Example 1
```powershell
PS C:\> Add-PSPackageProjectCmdletHelp -ProjectRoot . -ModuleName 'MyModule'
```

Updates the project cmdlet help for the module `MyModule`
when run from the project root directory of `MyModule`.

## PARAMETERS

### -ProjectRoot
The path to the repository root of the module.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleName
The name of the module to generate cmdlet help for.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Culture
The culture in which cmdlet help should be created.

```yaml
Type: CultureInfo
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
