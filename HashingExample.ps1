function HashFromSpec()
{
    [cmdletBinding()]
    param(
        [string]$hashSpec
    )
    $myHash = @{}
    ($hashSpec -split " ") | % { $myHash.add( ($_ -split "=")[0], (Invoke-Expression ($_ -split "=")[1] )) }
    $myHash
}

HashFromSpec -hashSpec "a=1/2 b=1/3 c=1tb d=2.5 e=1"
