Describe "PSPackageProject tests" {
    BeforeAll {
        $config = Get-PSPackageProjectConfiguration
    }

    It "Can find the TestPath" {
        $config.TestPath | Should -Exist
        $config.TestPath | Should -Be $PSScriptRoot
    }

    It "Can find the SourcePath" {
        $config.SourcePath | Should -Exist
        $config.SourcePath | Should -Be (Resolve-Path "$PSScriptRoot/../src").Path
    }

    It "Can find the HelpPath" {
        $config.HelpPath | Should -Exist
        $config.HelpPath | Should -Be (Resolve-Path "$PSScriptRoot/../help").Path
    }

    It "Can find the ModuleName" {
        $config.ModuleName | Should -Be 'PSPackageProject'
    }
}
