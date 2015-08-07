[cmdletBinding()]
param(
	#Game constants. Should probably become possible input parameters.
    $const_combat_max_rounds = 3
	
	#Initial Configuration. Should probably become possible input parameters
,   $bpCostSpec              = "PD=1 B=1 S=1 T=1 M=1/3 SR=1 C=1 SH=1/6 A=1/2 E=1 H=1/10 R=5 CP=15 SWG=3 MWG=5 LWG=10 SB=25"
,   $maxSizeSpec             = "SWG=15 MWG=60 LWG=250 SB=1000"
,   $pdPerMPSpec             = "SWG=1 MWG=2 LWG=3 SB=9999"
,   $hullSpec                = "SWG=1 MWG=4 LWG=16 SB=64 A=1 PD=1 CP=5"

    #Template and combatant warship specs                          
,   $templateAttrSpec        = "PD=0 B=0 S=0 T=0 M=0 SR=0 C=0 SH=0 A=0 E=0 H=0 R=0 CP=0 SWG=0 MWG=0 LWG=0 SB=0 BPCost=0 MaxSize=0 PDPerMP=0 Hull=0"
,   $templateInfoSpec        = "Name=TS1_-_Template_Ship Owner=Template_Owner Location=COORD[0,0] Universe=Reign_Of_Stars"
,   $templateSpec            = ("{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec)
,   $WS1Spec                 = ("{0} -- {1}" -f "Name=WSI-01-001_-_Gladius_001 Owner=Empire Location=COORD[1,1]", "SWG=1 MWG=1 PD=4 B=2 S=1")
,   $WS2Spec                 = ("{0} -- {1}" -f "Name=WSR-01-001_-_Vulpine_001 Owner=Rebels Location=COORD[2,2]", "SWG=1 SB=1 PD=4 T=1 S=1 M=3")
)
	
$onDebugAction   = "Continue"

if($PSBoundParameters['Debug']) { $debugPreference = $onDebugAction }

function main()
{
    [cmdletbinding()]
    param(
        [string[]]$argList
    )
		
    Write-Verbose "Initializing game objects..."
	
    $shipObjects = initializeGameObjects $argList
	Write-Verbose "Game objects initialized."
	
	Write-Verbose "Starting ships' state:"
    Write-Host ( WriteSummary -shipSet $shipObjects | Out-String)
	
	Write-Verbose "Begin combat!"
	1..$const_combat_max_rounds | foreach {
		Write-Verbose "Begin Round $_"
		$result = Evaluate-CombatRound -ships $shipObjects
		Write-Verbose (WriteSummary -shipSet $shipObjects | Out-String)
		Write-Verbose "End Round $_ - result code: $result"
		Write-Verbose ""
	}
	
	Write-Verbose "End combat!"
	
	
}

#region Combat execution
function Evaluate-CombatRound()
{
	[cmdletBinding()]
	param(
		[HashTable[]] $ships
	)
	
	return -1
}

#endregion

#region Game-object loading functions
function initializeGameObjects()
{
    [cmdletbinding()]
    param(
        [string[]]$argList
    )
	
    $shipObjects = @()
    $WSSpecs     = @($WS1Spec, $WS2Spec)

    Write-Debug " - Loading numeric cost spec..."
    $bpCostsLookup = HashFromSpec -hashSpec $bpCostSpec  -numeric
	Write-Debug (WriteLookupTable $bpCostsLookup | % {if($_ -ne "") {"        |$_ |"} else {$_} } | Out-String)
    
	Write-Debug " - Loading max size spec..."
	$maxSizeLookup = HashFromSpec -hashSpec $maxSizeSpec -numeric
	Write-Debug(WriteLookupTable $maxSizeLookup | % {if($_ -ne "") {"        |$_ |"} else {$_} } | Out-String)
	
    Write-Debug " - Loading PD-Per-MP spec..."
	$pdPerMPLookup = HashFromSpec -hashSpec $pdPerMPSpec -numeric
	Write-Debug(WriteLookupTable $pdPerMPLookup | % {if($_ -ne "") {"        |$_ |"} else {$_} } | Out-String)
    
	Write-Debug " - Loading Hull value spec..."
	$hullLookup    = HashFromSpec -hashSpec $hullSpec    -numeric
	Write-Debug(WriteLookupTable $hullLookup    | % {if($_ -ne "") {"        |$_ |"} else {$_} } | Out-String)
	

    Write-Debug " - Loading ship template..."
    $shipTemplate = loadShip -spec $templateSpec
    
    Write-Debug " - Loading real ships..."
    $WSSpecs | foreach { 
		$newShip = loadShip -spec $_ -template $shipTemplate -myBPCostsLookup $bpCostsLookup -myMaxSizeLookup $maxSizeLookup -myPDPerMPLookup $pdPerMPLookup -myHullLookup $hullLookup; 
		$shipObjects += @($newShip); 
		}

    Write-Debug ( "Complete! Initialized {0} ships" -f $shipObjects.Count)
    Write-Debug( WriteSummary -shipSet (@($shipTemplate)+$shipObjects) -includeZeroes | Out-String )

	return $shipObjects
}


function loadShip($spec, $template, $myBPCostsLookup, $myMaxSizeLookup, $myPDPerMPLookup, $myHullLookup)
{
    $infoSpec, $attrSpec = ($spec -split " -- ")
    Write-Debug "  -- Loading text info ..."
    $ship = HashFromSpec -hashSpec $infoSpec
    Write-Debug "  -- Loading numeric attributes ..."  
    $ship["attrs"]= HashFromSpec -hashSpec $attrSpec -numeric

    Write-Debug "  Post-Process..."
    Write-Debug "  -- Instantiate all templated values not overridden by spec"
      if($template -ne $null) { $template.GetEnumerator() | ? {$_.Key -ne "attrs" } | % { if (-not $ship.ContainsKey($_.Key)) {$ship.add($_.Key, $_.Value) } } }
      if($template -ne $null) { $template.attrs.GetEnumerator() | % { if (-not $ship.attrs.ContainsKey($_.Key)) {$ship.attrs.add($_.Key, $_.Value) } } }
    Write-Debug "  -- Calculate BP cost based on cost spec and unit attributes"
      $ship.attrs.BPCost  = calcBPCost           -attrSet $ship.attrs -costSpec $myBPCostsLookup
    Write-Debug "  -- Calculate maxSize attr for $ship.Name based on maxSizeSpec and SWG/MWG/LWG/SB allocation $myMaxSizeLookup"
	  $ship.attrs.maxSize = calcDerivedValue -attrSet $ship.attrs -depSpec  $myMaxSizeLookup
    Write-Debug "  -- Calculate PDPerMP attr for $ship.Name based on pdPerMPSpec and SWG/MWG/LWG/SB allocation $myPDPerMPLookup"
	  $ship.attrs.PDPerMP = calcMonoDerivedValue -attrSet $ship.attrs -depSpec  $myPDPerMPLookup
    Write-Debug "  -- Calculate Hull based on hullSpec and SWG/MWG/LWG/SB allocation, Armor, ..."
	#$ship.attrs.Hull      = (calcMultiDerivedValue  -attrSet $ship.attrs -depSpec $myHullLookup | measure-object sum).sum
	  
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
	
	if ($depSpec -eq $null) { Write-Debug "calcMonoDerivedValue call made with a null lookup table, will return -1" }
	
	# Only nonzero attributes matter, AND only evaluate if lookup table is non-null
	$attrSet.GetEnumerator() | ? { $_.Value -ne 0 -and $depSpec -ne $null } | foreach { 
		write-Debug ("     calcMonoDerivedValue enumerate over {0}:{1} against depSpec {2}" -f $_.Key, $_.Value, $depSpec)
		if($depSpec.ContainsKey($_.Key)) { 
			$newDerivedValue = $depSpec[$_.Key]
			Write-Debug ("          Found deriving attribute {0} which yields {1}" -f $_.Key, $depSpec[$_.Key])
			if ($derivedValue -eq $null -or ($minResult -and $newDerivedValue -lt $derivedValue) -or ($newDerivedValue -gt $derivedValue))
			{
				$derivedValue = $newDerivedValue
			}
		} 
		write-Debug ("     Done! candidate is {0}" -f $derivedValue)
	}
	
	if($derivedValue -eq $null) { $derivedValue = -1 }
	
	$derivedValue
}

function get-DerivedValueSet()
{
	[cmdletBinding()]
	param(
		 [HashTable] $attrSet, 
		 [HashTable] $depSpec
	)
	
	if ($depSpec -eq $null) {
		Write-Debug "calcMonoDerivedValue call made with a null lookup table, will return -1" 
		return -1
	}
	
	# Only nonzero attributes matter, AND only evaluate if lookup table is non-null
	$attrSet.GetEnumerator() | ? { $_.Value -ne 0 -and $depSpec -ne $null } | foreach { 
		write-Debug ("     calcMonoDerivedValue enumerate over {0}:{1} against depSpec {2}" -f $_.Key, $_.Value, $depSpec)
		if($depSpec.ContainsKey($_.Key)) { 
			return $depSpec[$_.Key] * $_.Value
		} 
	}
}
#endregion

#endregion

#region Print Functions
function printShipInfo
{
    [cmdletBinding()]
	param(
		[HashTable] $s,
		[switch] $includeZeroes
	); 
	
    $AttrSummary   = "| "
	$s.attrs.GetEnumerator() | ? { ($_.Value -ne 0) -or $includeZeroes -eq $true } | % { $AttrSummary += ("{0,-10}:{1,10} |`n{2} | " -f $_.Key, $_.Value, (" "*15))  }
	$AttrSummary += ("-"*21)+" |"
	
	#Return
    $s.GetEnumerator() | % { if($_.Key -ne "attrs") { "{0,-15} -- {1}" -f $_.Key, $_.Value } } 
    "{0,-15} {1}" -f "Attributes", $AttrSummary
}

function WriteSummary()
{
    [cmdletBinding()]
	param(
		$shipSet,
		[switch]    $includeZeroes
	)
    ($shipSet) | % {
		''
		'*'*45
		if($includeZeroes) { printShipInfo -s $_ -includeZeroes }
		else               { printShipInfo -s $_                }
		'*'*45
		''
	}
}

function WriteLookupTable()
{
    [cmdletBinding()]
	param(
		[HashTable] $t
	)
    ''
	' '+'*'*44
    $t.GetEnumerator() | % { " {0,-15} -- {1,25}" -f $_.Key, $_.Value }
    ' '+'*'*44
	''
}
#endregion

main($args)# -Verbose

