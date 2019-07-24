# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Describe "BinSkim" {
    BeforeAll{
        $outputPath =  Join-Path -Path ([System.io.path]::GetTempPath()) -ChildPath 'pspackageproject-results.json'
        $results = Get-Content $outputPath | ConvertFrom-Json
    }

    foreach($file in $results.runs.files.PsObject.Properties.Name)
    {
        foreach($rule in $results.runs.rules.psobject.properties.name)
        {
            $fileResults = @($results.runs.results |
                Where-Object {
                    Write-Verbose "$($_.ruleId) -eq $rule"
                    $_.locations.analysisTarget.uri -eq $File -and $_.ruleId -eq $rule})

            $message = $null
            if($fileResults.Count -ne 0) {
                $fileResult = $fileResults[0]
                $message = $results.runs.rules.$rule.messageFormats.($fileResult.Level) -f ($fileResult.formattedRuleMessage.arguments)
            }

            if($message){
                it "$file should not have errors for " {
                    throw $message
                }
            }
        }
    }
}
