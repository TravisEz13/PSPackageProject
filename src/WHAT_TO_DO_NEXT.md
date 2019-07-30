# What To Do Next

## Initialize the Project

To initialize a new PowerShell module, please run `Initialize-PSPackageProject -ModuleName MyTestMod -ModuleBase d:\temp\MyTestMod`.

The command will generate a scaffolding for the PowerShell module called `MyTestMod` at `d:\temp\MyTestMod`.

## Generated project scaffold

The following project structure is generated:

```PowerShell
PS D:\> dir D:\temp\MyTestMod\


    Directory: D:\temp\MyTestMod

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----           7/29/2019  4:08 PM                .ci
d----           7/29/2019  4:08 PM                help
d----           7/29/2019  4:08 PM                src
d----           7/29/2019  4:08 PM                test
-a---           7/29/2019  3:45 PM           3032 build.ps1
-a---           7/29/2019  4:08 PM            157 pspackageproject.json
```

`build.ps1` can be used to build and test the module.

Build the module: `build.ps1 -Build`
Test the module: `build.ps1 -Test`

### Deep-dive into individual folders

#### Source code

The scaffolding that is generated has stubs for both script cmdlet as well as binary cmdlet.
The module writer should delete the `code` folder if the module is a script module.

```PowerShell

    Directory: D:\temp\MyTestMod\src

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----           7/29/2019  4:08 PM                code
-a---           7/29/2019  4:08 PM           4174 MyTestMod.psd1
-a---           7/29/2019  4:08 PM              0 MyTestMod.psm1

    Directory: D:\temp\MyTestMod\src\code

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           7/29/2019  4:08 PM            353 Class1.cs
-a---           7/29/2019  4:08 PM            253 MyTestMod.csproj

```

#### Test code

The sample test is generated which can be executed using `build.ps1`.

```PowerShell

    Directory: D:\temp\MyTestMod\test

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           7/29/2019  4:08 PM            281 MyTestMod.Tests.ps1

```

#### Help content

The MD file for `about_Help` topic is created.
Cmdlet help can be generated when the module is built.

```PowerShell

    Directory: D:\temp\MyTestMod\help

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----           7/29/2019  4:08 PM                en-US

    Directory: D:\temp\MyTestMod\help\en-US

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           7/29/2019  4:08 PM           1460 about_MyTestMod.md

```

#### CI templates

The YAML files are stubs that are need to configure CI/CD pipelines on Azure DevOps.

```PowerShell
    Directory: D:\temp\MyTestMod\.ci

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           7/29/2019  3:45 PM           1855 ci.yml
-a---           7/29/2019  3:45 PM           2028 release.yml
-a---           7/29/2019  3:45 PM           2028 test.yml

```

## Build customization

The generated `build.ps1` file has a function called `DoBuild`.
Customize this function to suit your build needs.
When the function is executed, the expectation is that the `BuildOutputPath` as a sub-folder for the module with all required assemblies and script assests.

## Enable CI in Azure DevOps

For maintaining quality of the module, it is highly recommended that a CI system should be used.
We recommend using Azure DevOps, and hence assist onboarding by creating YAML files for the same.

The `.ci/ci.yml` file defines the YAML for building the module and testing it on `Windows`, `Linux` and `macOS`.
This can be further customized according to your needs.

The `.ci/release.yml` file defines the YAML for the release pipeline, which can be used to publish the module to [PowerShell Gallery](https://www.powershellgallery.com).

For more information about getting started with configuring an Azure DevOps build pipeline refer the following links:

https://docs.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=tfs-2018-2
https://docs.microsoft.com/en-us/azure/devops/pipelines/customize-pipeline?view=azure-devops

When, you have your Azure DevOps project setup, create a new pipeline and use the `ci.yml` file.
This will setup the build pipeline for PRs and merges.

To setup the release pipeline, create a new release pipeline and use the `release.yml` file.
Remember to define a pipeline variable called `NuGetApiKey` with the value of the API key to publish module to the gallery.
