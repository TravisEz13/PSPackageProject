# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

function Invoke-PSPackageProjectTest
{
    param(
        [Parameter()]
        [ValidateSet("Functional", "StaticAnalysis")]
        [string]
        $Type
    )
}
