---
external help file: PSPackageProject-help.xml
Module Name: PSPackageProject
online version:
schema: 2.0.0
---

# Export-PSPackageProjectHelp

## SYNOPSIS
Assembles help files into staging output.

## SYNTAX

```
Export-PSPackageProjectHelp [-ProjectRoot] <String> [-ModuleName] <String> [[-Culture] <CultureInfo>]
 [<CommonParameters>]
```

## DESCRIPTION
Compiles markdown help resources into
PowerShell external help files and places
them into the staging location.

## EXAMPLES

### Example 1
```powershell
PS C:\> Export-PSPackageProjectHelp -ProjectRoot . -ModuleName 'MyModule'
```

Builds the module project `MyModule` when the project root is the current directory.
If `./help` contains `about_MyModule.md` and `Get-Thing.md`,
and the current culture (`[cultureinfo]::CurrentCulture`) is `en-US`,
this adds `about_MyModule.txt` and `MyModule-help.xml`
to `./out/help/en-US`.

## PARAMETERS

### -ProjectRoot
The path to the project repository root.

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
The name of the module to publish help for.

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
The locale or culture the help is written for.

```yaml
Type: CultureInfo
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: [cultureinfo]::CurrentCulture
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
