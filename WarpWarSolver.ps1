function main($argList)
{
    $templateAttrSpec= "PD:0 B:0 S:0 T:0 M:0 SR:0 C:0 SH:0 A:0 E:0 H:0 R:0 CP:0 SWG:0 MWG:0 LWG:0"
    $templateInfoSpec= "Name:Template_Ship Owner:Template_Owner Location:COORD[0,0]"
    $templateSpec    = "{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec

    $shipTemplate    = loadShip -spec $templateSpec
    
    $WS1Spec    = "Name:WS1 Owner:Imperium Location:COORD[1,1] -- SWG:1 PD:4 B:2 S:1"
    $WS2Spec    = "Name:WS2 Owner:Rebels Location:COORD[2,2] -- SWG:1 PD:3 T:1 S:1 M:3"

    $WS1        = loadShip -spec $WS1Spec -template $shipTemplate
    $WS2        = loadShip -spec $WS2Spec -template $shipTemplate

    ""
    "*******************************************************"
    printShipInfoVerbose $shipTemplate
    "*******************************************************"
    ""

    ""
    "*******************************************************"
    printShipInfo $WS1
    "*******************************************************"
    ""

    ""
    "*******************************************************"
    printShipInfo $WS2
    "*******************************************************"
    ""

    return
}

function loadShip($spec, $template)
{
    write-host "
    Loading spec 
      [$spec] 
    Starting from 
       [$template]"

    #clone template ship info and attributes
    $ship = @{}
    if ($template -eq $null) 
    { 
        $ship          = @{}
        $ship["attrs"] = @{} 
    } 
    else 
    { 
        $ship = $template.Clone()
        $ship["attrs"]=$template.attrs.Clone() 
    }

    $infoSpec, $attrSpec = ($spec -split " -- ")
    $infoSpec -split " " | % { $k, $v = $_ -split ":"; $ship[      "$k"]=$v; }
    $attrSpec -split " " | % { $k, $v = $_ -split ":"; $ship.attrs["$k"]=$v; }

    return $ship
}

function printShipInfoVerbose
{
    [HashTable] $s = $args[0]
    $AttrSummary   = ""
    $s.GetEnumerator() | % { if($_.Key -ne "attrs") {$_} }

    $s.attrs.GetEnumerator() | % { $AttrSummary += $_.Key + ":" + $_.Value + " " }
    "Attributes:
    $AttrSummary"
}

function printShipInfo
{
    [HashTable] $s = $args[0]
    $AttrSummary   = ""
    $s.GetEnumerator() | % { if($_.Key -ne "attrs") {$_} }

    $s.attrs.GetEnumerator() | ? { $_.Value -ne 0 } | % { $AttrSummary += $_.Key + ":" + $_.Value + " " }
    "Attributes:
    $AttrSummary"
    
}


main($args);

