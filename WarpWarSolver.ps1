[cmdletBinding()]
param(
	#Game constants. Should probably become possible input parameters.
    $const_combat_max_rounds = 3
	
	#Initial Configuration. Should probably become possible input parameters
,   $BPCostSpec              = "PD=1 B=1 S=1 T=1 M=1/3 SR=1 C=1 SH=1/6 A=1/2 E=1 H=1/10 R=5 CP=15 SWG=3 MWG=5 LWG=10 SB=25"
,   $maxSizeSpec             = "SWG=12 MWG=50 LWG=200 SB=800 SSS=4 MSS=16 LSS=64 GSS=256"
,   $pdPerMPSpec             = "SWG=1 MWG=2 LWG=3 SB=9999 SSS=9999 MSS=9999 LSS=9999 GSS=9999"
,   $hullSpec                = "SWG=1 MWG=4 LWG=16 SB=64 A=1 PD=1 CP=5 SR=1"

    #Template and combatant warship specs                          
,   $templateInfoSpec        = "Name=TS1_-_Template_Ship Owner=Template_Owner Location=COORD[0,0] Universe=Reign_Of_Stars Valid=???"
,   $templateAttrSpec        = "PD=0 B=0 S=0 T=0 M=0 SR=0 C=0 SH=0 A=0 E=0 H=0 R=0 CP=0 SWG=0 MWG=0 LWG=0 SB=0 _BPCost=0 _MaxSize=0 _PDPerMP=0 _Hull=0"
,   $templateSpec            = ("{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec)
,   $WS1Spec                 = ("{0} -- {1}" -f "Name=WSI-01-001_-_Gladius_001 Owner=Empire Location=COORD[1,1]", "SWG=1 MWG=1 PD=4 B=2 S=1")
,   $WS2Spec                 = ("{0} -- {1}" -f "Name=WSR-01-001_-_Vulpine_001 Owner=Rebels Location=COORD[2,2]", "SWG=1 PD=54 T=1 S=1 M=3")

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
    $BPCostsLookup = HashFromSpec -hashSpec $BPCostSpec  -numeric
	Write-Debug (WriteLookupTable $BPCostsLookup | % {if($_ -ne "") {"        |$_ |"} else {$_} } | Out-String)
    
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
		$newShip = loadShip -spec $_ -template $shipTemplate -myBPCostsLookup $BPCostsLookup -myMaxSizeLookup $maxSizeLookup -myPDPerMPLookup $pdPerMPLookup -myHullLookup $hullLookup; 
		$shipObjects += @($newShip); 
		}

    Write-Debug ( "Init Complete! Initialized {0} ships" -f $shipObjects.Count)
    Write-Debug( WriteSummary -shipSet (@($shipTemplate)+$shipObjects) -includeZeroes | Out-String )

	return $shipObjects
}

function validate-GameObject()
{
	[cmdletBinding()]
	param(
		[alias ("Game-Object")]
		$GO 
	)
	write-Verbose "Validating $($GO.Name)"
		
	$GOa = $GO.attrs
	
	#Game-Object should only have one _MaxSize/_PDPerMP-defining component (*WG or SB or *SS)
	write-debug ("Hull uniqueness? -- SWG:{0}, MWG:{1}, LWG:{2}, SB:{3}" -f $GOa.SWG, $GOa.MWG, $GOa.LWG, $GOa.SB)
	if($GOa.SWG + $GOa.MWG + $GOa.LWG + $GOa.SB -gt 1) { "Multiple WarpGen and/or SB components" }
	
	#_BPCost should be less than _MaxSize
	write-debug ("_BPCost within threshold? -- _BPCost:{0}, _MaxSize:{1}" -f $GOa._BPCost, $GOa._MaxSize)
	if($GOa._BPCost -gt $GOa._MaxSize) { "BP Cost {0} Exceeds Maximum {1} for Hull/Drive Type" -f $GOa._BPCost, $GOa._MaxSize }
	
	#Attributes probably shouldn't be negative
	write-debug ("")
	if(($GOa.GetEnumerator() | ? { $_.Value -lt 0 } | Measure-Object).Count -gt 0) {"One or more attrs are negative"}
	
	#Hangar space ( SR attr * _Hull attr )cannot be exceeded by hull sizes of attached units.
	write-debug ("Sum of parasite hulls ({0}) less than parent-hull times SR attribute ({1})?" -f 0, ($GOa._Hull*$GOa.SR))
	if(($GOa._Hull * $GOa.SR) -lt 0) {"Hangar maximum {0} exceeded by attached units {1}" -f ($GOa._Hull * $GOa.SR), 0}

	# ??? Stricter variant -- EACH SR cannot accommodate a unit bigger than parent's _Hull
	# ...
}


function loadShip($spec, $template, $myBPCostsLookup, $myMaxSizeLookup, $myPDPerMPLookup, $myHullLookup)
{
    $infoSpec, $attrSpec = ($spec -split " -- ")
    Write-Debug "  Load Ship Specs..."
    $ship                    = HashFromSpec -hashSpec $infoSpec
    $ship["attrs"]           = HashFromSpec -hashSpec $attrSpec -numeric
	$ship["validationNotes"] = @()

    Write-Debug "  Post-Process..."
    Write-Debug "  -- Instantiate all templated values not overridden by spec"
      if($template -ne $null) { $template.GetEnumerator() | ? {$_.Key -ne "attrs" } | % { if (-not $ship.ContainsKey($_.Key)) {$ship.add($_.Key, $_.Value) } } }
      if($template -ne $null) { $template.attrs.GetEnumerator() | % { if (-not $ship.attrs.ContainsKey($_.Key)) {$ship.attrs.add($_.Key, $_.Value) } } }
    Write-Debug "  -- Calculate BP cost based on cost spec and unit attributes"
	  $ship.attrs._BPCost  = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec $myBPCostsLookup)  | measure-object -sum).sum
    Write-Debug "  -- Calculate _MaxSize attr for $ship.Name based on maxSizeSpec and SWG/MWG/LWG/SB allocation $myMaxSizeLookup"
	  $ship.attrs._MaxSize = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec  $myMaxSizeLookup) | measure-object -maximum).maximum
    Write-Debug "  -- Calculate _PDPerMP attr for $ship.Name based on pdPerMPSpec and SWG/MWG/LWG/SB allocation $myPDPerMPLookup"
	  $ship.attrs._PDPerMP = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec  $myPDPerMPLookup) | measure-object -maximum).maximum  
    Write-Debug "  -- Calculate _Hull based on hullSpec and S*/M*/L*/H*/SB allocation, PD, SR, CP, A, ..."
	  $ship.attrs._Hull    = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec  $myHullLookup)    | measure-object -sum).sum
	  
    $ship["validationNotes"] = validate-GameObject -Game-Object $ship
	if($ship.validationNotes -eq $null -or $ship.validationNotes.Count -eq 0) {$ship.Valid="true"} 
	else {$ship.Valid="false"}
	
	return $ship
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

function get-DerivedValueSet()
{
	[cmdletBinding()]
	param(
		 [HashTable] $attrSet, 
		 [HashTable] $depSpec
	)
	
	if ($depSpec -eq $null) {
		Write-Debug "get-derivedValueSet call made with a null lookup table, will return -1" 
		return -1
	}
	
	# Only nonzero attributes matter, AND only evaluate if lookup table is non-null
	$attrSet.GetEnumerator() | ? { $_.Value -ne 0 -and $depSpec -ne $null } | foreach { 
		write-Debug ("     get-derivedValueSet enumerate over {0}:{1} against depSpec {2}" -f $_.Key, $_.Value, $depSpec)
		if($depSpec.ContainsKey($_.Key)) { 
			return $depSpec[$_.Key] * $_.Value
		} 
	}
}
#endregion

#region Print Functions
function printShipInfo
{
    [cmdletBinding()]
	param(
		[HashTable] $s,
		[switch] $includeZeroes
	); 
	
    $AttrSummary  = "| "
	$s.attrs.GetEnumerator() | sort name | ? { ($_.Value -ne 0) -or $includeZeroes -eq $true } | % { $AttrSummary += ("{0,-10}:{1,10} |`n{2} | " -f $_.Key, $_.Value, (" "*15))  }
	$AttrSummary += ("-"*21)+" |"
	
	#Return
    $s.GetEnumerator() | % { if($_.Key -ne "attrs" -and $_.Key -ne "validationNotes" -and $_.Key -ne "Valid") { "{0,-15} | {1}" -f $_.Key, $_.Value } } 
    "{0,-15} {1}" -f "Attributes", $AttrSummary
	if($s.Valid -eq "false") { "{0}:`n  - {1}"   -f "INVALID", ($s.validationNotes -join "`n  - ") }
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

