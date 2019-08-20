Describe "PSPackageProject tests" -Tag "CI" {
    BeforeAll {
        # Create test case for this project
        $testCases = @()
        $config = Get-PSPackageProjectConfiguration
        $expectedRootPath = (Resolve-Path "$PSScriptRoot/..").providerPath
        $signedRoot = (Join-Path -Path $expectedRootPath -ChildPath 'signed')
        if ( ! (Test-Path -Path $signedRoot)) {
            $null = New-Item -ItemType Directory -Path (Join-Path -Path $expectedRootPath -ChildPath 'signed')
        }

        $testCases += @{
            config = $config
            expectedRootPath = $expectedRootPath
            name = 'This Project'
            moduleName = 'PSPackageProject'
        }

        # Create Older json test case
        $expectedRootPath = Join-Path -Path $testdrive -ChildPath 'testcase'
        Initialize-PSPackageProject -ModuleName testcase -ModuleBase $expectedRootPath
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $expectedRootPath -ChildPath 'signed')
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $expectedRootPath -ChildPath 'out')
        $jsonPrj =
            @{
                SourcePath = "src"
                ModuleName = "testcase"
                TestPath = 'test'
                HelpPath = 'help'
                BuildOutputPath = 'out'
                Culture = [CultureInfo]::CurrentCulture.Name
            } | ConvertTo-Json
        $configPath = "$expectedRootPath/pspackageproject.json"
        $jsonPrj | Out-File -FilePath $configPath
        $config = Get-PSPackageProjectConfiguration $configPath

        $testCases += @{
            config = $config
            expectedRootPath = $expectedRootPath
            name = 'Older Json'
            moduleName = 'testcase'
        }
    }

    It "Can find the TestPath - <name>" -TestCases $testCases {
        param(
            $config,
            $expectedRootPath,
            $name
        )

        $config.TestPath | Should -Exist
        $config.TestPath | Should -Be (Join-Path -Path $expectedRootPath -ChildPath "/test")
    }

    It "Can find the BuildOutputPath - <name>" -TestCases $testCases {
        param(
            $config,
            $expectedRootPath,
            $name
        )

        $config.BuildOutputPath | Should -Exist
        $config.BuildOutputPath | Should -Be (Join-Path -Path $expectedRootPath -ChildPath "/out")
    }

    It "Can find the SignedOutputPath - <name>" -TestCases $testCases {
        param(
            $config,
            $expectedRootPath,
            $name
        )

        $config.SignedOutputPath | Should -Exist
        $config.SignedOutputPath | Should -Be (Join-Path -Path $expectedRootPath -ChildPath "/signed")
    }


    It "Can find the SourcePath - <name>" -TestCases $testCases {
        param(
            $config,
            $expectedRootPath,
            $name
        )

        $config.SourcePath | Should -Exist
        $config.SourcePath | Should -Be (Join-Path -Path $expectedRootPath -ChildPath "/src")
    }

    It "Can find the HelpPath - <name>" -TestCases $testCases {
        param(
            $config,
            $expectedRootPath,
            $name
        )

        $config.HelpPath | Should -Exist
        $config.HelpPath | Should -Be (Join-Path -Path $expectedRootPath -ChildPath "/help")
    }

    It "Can find the ModuleName - <name>" -TestCases $testCases {
        param(
            $config,
            $moduleName,
            $name
        )
        $config.ModuleName | Should -Be $moduleName
    }
}
