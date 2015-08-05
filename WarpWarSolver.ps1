$bpCostSpec      = "PD=1 B=1 S=1 T=1 M=1/3 SR=1 C=1 SH=1/6 A=1/2 E=1 H=1/10 R=5 CP=15 SWG=3 MWG=5 LWG=10 SB=25"
$templateAttrSpec= "PD=0 B=0 S=0 T=0 M=0 SR=0 C=0 SH=0 A=0 E=0 H=0 R=0 CP=0 SWG=0 MWG=0 LWG=0 SB=0"
$templateInfoSpec= "Name=TS1_-_Template_Ship Owner=Template_Owner Location=COORD[0,0] BPCost=0 Universe=Reign_Of_Stars"
$templateSpec    = "{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec

$WS1Spec    = "Name=WSI-01-001_-_Gladius_001 Owner=Empire Location=COORD[1,1] -- SWG=1 PD=4 B=2 S=1"
$WS2Spec    = "Name=WSR-01-001_-_Vulpine_001 Owner=Rebels Location=COORD[2,2] -- SWG=1 PD=4 T=1 S=1 M=3"


function main()
{
    [cmdletbinding()]
    param(
        [string[]]$argList
    )
    
    $shipObjects = initializeGameObjects $argList

    WriteSummary -shipSet $shipObjects
}

function initializeGameObjects()
{
    [cmdletbinding()]
    param(
        [string[]]$argList
    )
    
    $shipObjects = @()
    $WSSpecs     = @($WS1Spec, $WS2Spec)

    Write-Debug "Loading numeric cost spec..."
    $bpCosts = HashFromSpec -hashSpec $bpCostSpec -numeric

    Write-Debug "Loading ship template..."
    $shipTemplate = loadShip -spec $templateSpec
    
    Write-Debug "Loading real ships..."
    $WSSpecs | % { $newShip = loadShip -spec $_ -template $shipTemplate -costSpec $bpCosts; $shipObjects += @($newShip); }

    WriteCostSummary -costSpec $bpCosts | % { $_ } | Out-String | Write-Verbose
    WriteSummary     -verboseSet (@($shipTemplate)+$shipObjects) -shipSet $null | Out-String | Write-Verbose

    return $shipObjects
}

#Text-to-object loading functions

function loadShip($spec, $template, $costSpec)
{

    $infoSpec, $attrSpec = ($spec -split " -- ")
    # Write-Host " -- Loading text info ..."
    $ship = HashFromSpec -hashSpec $infoSpec
    # Write-Host " -- Loading numeric attributes ..."
    $ship["attrs"]= HashFromSpec -hashSpec $attrSpec -numeric

    #Post-Process
    # -- Instantiate all templated values not overridden by spec
      if($template -ne $null) { $template.GetEnumerator() | ? {$_.Key -ne "attrs" } | % { if (-not $ship.ContainsKey($_.Key)) {$ship.add($_.Key, $_.Value) } } }
      if($template -ne $null) { $template.attrs.GetEnumerator() | % { if (-not $ship.attrs.ContainsKey($_.Key)) {$ship.attrs.add($_.Key, $_.Value) } } }
    # -- Calculate BP cost based on cost spec and unit attributes
      $ship.BPCost = calcBPCost -attrSet $ship.attrs -costSpec $costSpec    

    return $ship
}

function calcBPCost ($attrSet, $costSpec)
{
    ($attrSet.GetEnumerator() | ? { $_.Value -ne 0 } | % { [decimal]::Ceiling( [decimal]$_.Value * [decimal]$costSpec[$_.Key] ); } | measure-object -sum).Sum
}

function HashFromSpec()
{
    [cmdletBinding()]
    param(
        [string]$hashSpec,
        [switch]$numeric
    )
    $myHash = @{}
    ($hashSpec -split " ") | foreach {
        $myKey=($_ -split "=")[0]
        $myVal=($_ -split "=")[1]
        if($numeric) { $myVal=Invoke-Expression $myVal }
        else         { $myVal=$myVal -replace "_", " " }
        $myHash.add($myKey, $myVal)
    }
    $myHash
}


#Print Functions

function printShipInfoVerbose
{
    [HashTable] $s = $args[0]
    $AttrSummary   = ""
    $s.GetEnumerator() | % { if($_.Key -ne "attrs") { "{0,-20} -- {1}" -f $_.Key, $_.Value } } 

    $s.attrs.GetEnumerator() | % { $AttrSummary += $_.Key + ":" + $_.Value + " " }
    "{0,-20} -- {1}" -f "Attributes", $AttrSummary
}

function printShipInfo
{
    [HashTable] $s = $args[0]
    $AttrSummary   = ""
    $s.GetEnumerator() | % { if($_.Key -ne "attrs") { "{0,-20} -- {1}" -f $_.Key, $_.Value } } 

    $s.attrs.GetEnumerator() | ? { $_.Value -ne 0 } | % { $AttrSummary += $_.Key + ":" + $_.Value + " " }
    "{0,-20} -- {1}" -f "Attributes", $AttrSummary
}

function WriteSummary($verboseSet, $shipSet)
{
    if($verboseSet -ne $null){
        ($verboseSet) | % {
            ""
            "*******************************************************"
            printShipInfoVerbose $_
            "*******************************************************"
            ""
        }
    }

    if($shipSet -ne $null){
        ($shipSet) | % {
            ""
            "*******************************************************"
            printShipInfo $_
            "*******************************************************"
            ""
        }
    }
}

function WriteCostSummary($costSpec)
{
    ""
    '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
    $costSpec.GetEnumerator() | % { "{0,-20} costs `${1}" -f $_.Key, $_.Value }
    '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
    ""
}

main($args) -Verbose

