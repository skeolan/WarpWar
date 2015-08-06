[cmdletBinding()]
param()

#Initial Configuration. Should probably become possible input parameters
$bpCostSpec      = "PD=1 B=1 S=1 T=1 M=1/3 SR=1 C=1 SH=1/6 A=1/2 E=1 H=1/10 R=5 CP=15 SWG=3 MWG=5 LWG=10 SB=25"
$maxSizeSpec     = "SWG=15 MWG=60 LWG=250 SB=1000"
$pdPerMPSpec     = "SWG=1 MWG=2 LWG=3 SB=9999"
$hullSpec        = "SWG=1 MWG=4 LWG=16 SB=64 A=1 PD=1"
$templateAttrSpec= "PD=0 B=0 S=0 T=0 M=0 SR=0 C=0 SH=0 A=0 E=0 H=0 R=0 CP=0 SWG=0 MWG=0 LWG=0 SB=0 BPCost=0 MaxSize=0 PDPerMP=0 Hull=0"
$templateInfoSpec= "Name=TS1_-_Template_Ship Owner=Template_Owner Location=COORD[0,0] Universe=Reign_Of_Stars"

$templateSpec    = "{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec
$WS1Spec         = "{0} -- {1}" -f "Name=WSI-01-001_-_Gladius_001 Owner=Empire Location=COORD[1,1]", "SWG=1 MWG=1 PD=4 B=2 S=1"
$WS2Spec         = "{0} -- {1}" -f "Name=WSR-01-001_-_Vulpine_001 Owner=Rebels Location=COORD[2,2]", "SWG=1 SB=1 PD=4 T=1 S=1 M=3"


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

    Write-Verbose "Loading numeric cost spec..."
    $bpCostsLookup = HashFromSpec -hashSpec $bpCostSpec  -numeric
	$bpCostsLookup | Out-String | Write-Verbose
    Write-Verbose "Loading max size spec..."
	$maxSizeLookup = HashFromSpec -hashSpec $maxSizeSpec -numeric
	$maxSizeLookup | Out-String | Write-Verbose
    Write-Verbose "Loading PD-Per-MP spec..."
	$pdPerMPLookup = HashFromSpec -hashSpec $pdPerMPSpec -numeric
	$pdPerMPLookup | Out-String | Write-Verbose
    Write-Verbose "Loading Hull value spec..."
	$hullLookup    = HashFromSpec -hashSpec $hullSpec    -numeric
	$hullLookup | Out-String | Write-Verbose
	

    Write-Verbose "Loading ship template..."
    $shipTemplate = loadShip -spec $templateSpec
    
    Write-Verbose "Loading real ships..."
    $WSSpecs | foreach { 
		$newShip = loadShip -spec $_ -template $shipTemplate -bpCostsLookup $bpCostsLookup -maxSizeLookup $maxSizeLookup -pdPerMPLookup $pdPerMPLookup -hullLookup $hullLookup; 
		$shipObjects += @($newShip); 
		}

    Write-Verbose "Writing summaries of loaded data..."
	WriteCostSummary -costSpec $bpCosts | % { $_ } | Out-String | Write-Verbose
    WriteSummary     -shipSet (@($shipTemplate)+$shipObjects) -includeZeroes | Out-String | Write-Verbose

    Write-Verbose ( "Complete! returning {0} initialized ships" -f $shipObjects.Count)
	return $shipObjects
}

#Text-to-object loading functions

function loadShip($spec, $template, $bpCostsLookup, $maxSizeLookup, $pdPerMPLookup, $hullLookup)
{
    $infoSpec, $attrSpec = ($spec -split " -- ")
    Write-Verbose "  -- Loading text info ..."
    $ship = HashFromSpec -hashSpec $infoSpec
    Write-Verbose "  -- Loading numeric attributes ..."  
    $ship["attrs"]= HashFromSpec -hashSpec $attrSpec -numeric

    Write-Verbose "  Post-Process..."
    Write-Verbose "  -- Instantiate all templated values not overridden by spec"
      if($template -ne $null) { $template.GetEnumerator() | ? {$_.Key -ne "attrs" } | % { if (-not $ship.ContainsKey($_.Key)) {$ship.add($_.Key, $_.Value) } } }
      if($template -ne $null) { $template.attrs.GetEnumerator() | % { if (-not $ship.attrs.ContainsKey($_.Key)) {$ship.attrs.add($_.Key, $_.Value) } } }
    Write-Verbose "  -- Calculate BP cost based on cost spec and unit attributes"
      $ship.attrs.BPCost  = calcBPCost           -attrSet $ship.attrs -costSpec $bpCostsLookup
    Write-Verbose "  -- Calculate maxSize based on maxSizeSpec and SWG/MWG/LWG/SB allocation"
	  $ship.attrs.maxSize = calcMonoDerivedValue -attrSet $ship.attrs -depSpec  $maxSizeLookup
    Write-Verbose "  -- Calculate PDPerMP based on pdPerMPSpec and SWG/MWG/LWG/SB allocation"
	  $ship.attrs.PDPerMP = calcMonoDerivedValue -attrSet $ship.attrs -depSpec  $pdPerMPLookup
    Write-Verbose "  -- Calculate Hull based on hullSpec and SWG/MWG/LWG/SB allocation, Armor, ..."
	#  $ship.attrs.PDPerMP = calcSumDerivedValue  -attrSet $ship.attrs -depSpec ( HashFromSpec -hashSpec $hullSpec    -numeric )
	  
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

#If a single point of a single attribute determines a new ship's value, 
# this function uses a ship's attribute set plus the "lookup table" to find the derived value.
#    -- For example, a Small Warp Generator limits ship size to 9BP per the basic rules and costs 1 PD per MP.
# Default "max" behavior means if multiple ship attributes match the "lookup" spec, the highest result becomes the calculated result.
# Override this by passing the -minResult flag.
#    -- For example, a SWG and a MWG present on the same ship push the BP limit up to 45 and the PD per MP cost both up to 2. No MinResult flag needed.
#    -- Some theoretical optional attribute e.g. "FighterLaunchDelay" might want to defer toward minimum in the event of multiple qualifying attributes.
function calcMonoDerivedValue()
{
	[cmdletBinding()]
	param(
		 [HashTable] $attrSet, 
		 [HashTable] $depSpec,
		 [switch]    $minResult=$false
	)
	
	$derivedValue = $null
	
	# Only nonzero attributes matter
	$attrSet.GetEnumerator() | ? { $_.Value -ne 0 } | foreach { 
		write-Verbose ("     calcMonoDerivedValue enumerate over {0}:{1} against depSpec {2}" -f $_.Key, $_.Value, $depSpec)
		if($depSpec.ContainsKey($_.Key)) { 
			$newDerivedValue = $depSpec[$_.Key]
			Write-Verbose ("          Found deriving attribute {0} which yields {1}" -f $_.Key, $depSpec[$_.Key])
			if ($derivedValue -eq $null -or ($minResult -and $newDerivedValue -lt $derivedValue) -or ($newDerivedValue -gt $derivedValue))
			{
				$derivedValue = $newDerivedValue
			}
		} 
		write-Verbose ("     Done! candidate is {0}" -f $derivedValue)
	}
	
	if($derivedValue -eq $null) { $derivedValue = -1 }
	
	$derivedValue
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
    [cmdletBinding()]
	param(
		[HashTable] $s,
		[switch] $includeZeroes
	); 
	
    $AttrSummary   = ""
	$s.attrs.GetEnumerator() | ? { ($_.Value -ne 0) -or $includeZeroes -eq $true } | % { $AttrSummary += $_.Key + ":" + $_.Value + " " }
	
	#Return
    $s.GetEnumerator() | % { if($_.Key -ne "attrs") { "{0,-20} -- {1}" -f $_.Key, $_.Value } } 
    "{0,-20} -- {1}" -f "Attributes", $AttrSummary
}

function WriteSummary()
{
    [cmdletBinding()]
	param(
		$shipSet,
		[switch] $includeZeroes
	);
    ($shipSet) | % {
		""
		"*******************************************************"
		if($includeZeroes) { printShipInfo -s $_ -includeZeroes }
		else               { printShipInfo -s $_                }
		"*******************************************************"
		""
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

main($args)# -Verbose

