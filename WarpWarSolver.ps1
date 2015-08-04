$bpCostSpec      = @{ PD=1; B=1; S=1; T=1; M=1/3; SR=1; C=1; SH=1/6; A=1/2; E=1; H=1/10; R=5; CP=15; SWG=3; MWG=5; LWG=10; SB=25 }
$templateAttrSpec= "PD:0 B:0 S:0 T:0 M:0 SR:0 C:0 SH:0 A:0 E:0 H:0 R:0 CP:0 SWG:0 MWG:0 LWG:0 SB:0"
$templateInfoSpec= "Name:TS1_-_Template_Ship Owner:Template_Owner Location:COORD[0,0] BPCost:0"
$templateSpec    = "{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec

$WS1Spec    = "Name:WS1_-_Gladia_001 Owner:Empire Location:COORD[1,1] -- SWG:1 PD:4 B:2 S:1"
$WS2Spec    = "Name:WS2_-_Vulpis_001 Owner:Rebels Location:COORD[2,2] -- SWG:1 PD:4 T:1 S:1 M:3"

function main()
{
    [cmdletbinding()]
    param(
        [string[]]$argList
    )
    $shipTemplate    = loadShip    -spec     $templateSpec
    
    $WSSpecs     = @($WS1Spec, $WS2Spec)
    $shipObjects = @()

    $WSSpecs | % { $newShip = loadShip -spec $_ -template $shipTemplate -costSpec $bpCostSpec; $shipObjects += @($newShip); }

    WriteSummary     -verboseSet @($shipTemplate) -shipSet $shipObjects
    WriteCostSummary -costSpec $bpCostSpec | % { write-debug $_ }
    return
}

#Text-to-object loading functions

function loadShip($spec, $template, $costSpec)
{
    write-debug ("
    Loading spec  [{0}] starting from [{1}]" -f $spec, $template.Name)

    #clone template ship info and attributes
    $ship         = ($template,       @{} -ne $null)[0].Clone()
    $ship["attrs"]= ($template.attrs, @{} -ne $null)[0].Clone() 
    
    $infoSpec, $attrSpec = ($spec -split " -- ")
    $infoSpec -split " " | % { $k, $v = $_ -split ":"; $ship[      "$k"]=$v.Replace("_", " "); }
    $attrSpec -split " " | % { $k, $v = $_ -split ":"; $ship.attrs["$k"]=$v; }

    $ship.BPCost = calcBPCost -attrSet $ship.attrs -costSpec $costSpec

    return $ship
}

function calcBPCost ($attrSet, $costSpec)
{
    ($attrSet.GetEnumerator() | ? { $_.Value -ne 0 } | % { [decimal]::Ceiling( [decimal]$_.Value * [decimal]$costSpec[$_.Key] ); } | measure-object -sum).Sum
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
    ($verboseSet) | % {
        ""
        "*******************************************************"
        printShipInfoVerbose $_
        "*******************************************************"
        ""
    }

    ($shipSet) | % {
        ""
        "*******************************************************"
        printShipInfo $_
        "*******************************************************"
        ""
    }
}

function WriteCostSummary($costSpec)
{
    ""
    '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
    $costSpec
    '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
    ""
}

main($args);

