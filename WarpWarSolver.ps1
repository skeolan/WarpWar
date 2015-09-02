<# 

Attribute       	Abbr 	Description                                                                                       	BPCost	Damage
Power Drive     	(PD)	Represents the total effective strength of a ship's engines.                                     	 1   	-
Beams           	(B)    	Represent the ability of a ship to project a beam of destructive energy at a target.            	 1    	Strength of beam power +TL
Screens         	(S) 	represent the ability of a ship to surround itself with a protective energy screen.               	 1   	1 screen power absorbs 1 damage
Missile Tubes    	(T) 	are used by a ship to launch Missiles. Each Tube may launch one Missile per combat round.       	 1    	-
Missiles        	(M) 	may be fired through a ship's Tubes at an enemy ship.                                            	 1/3 	2 per missile + TL
Systemship Rack 	(SR) 	let a Warpship carry Systemships.                                                               	 1   	-
Cannons (opt)    	(C) 	are used by a ship to launch Shells. Each Cannon may fire either 1, 2 or 3 Shells per combat round.  1   	-
Shells (opt)    	(SH) 	are fired by Cannons.                                                                              	 1/6 	1 per shell + TL
Armor (opt)     	(A) 	is ablative hull reinforcement.                                                                 	 1/2 	1 point of armor absorb 1 damage
ECM (adv)       	(E) 	Electronic countermeasures.                                                                      	 1   	-
Hold (adv)      	(H) 	Holds contain BPs and allow Warpships to transport BPs between stars.                           	 1/10  	-
Repair Bay (adv)	(R) 	May use BPs in Hold or from Star to repair self or others during the build/repair event.        	 5   	Can not be damaged
Colony Pod (adv)	(CP) 	Establishes a new Colony when deployed.                                                         	15 Destroyed if enemy ship present and no friendly ships.

*** Hull Classes -- all BP limits are CC-dependent under the Reign of Stars rules, using formula (W*W + W*H)
Sat Hull         	---- 	Hull type. Immobile, can only defend. May base local Systemships.
  Small  Starbase   (SSB) 	For bases BP 64(H 8) or smaller. (Defsat)                                                          	 7 Destroyed if enemy ship present and no friendly ships
  Medium Starbase   (MSB) 	For bases BP144(H12) or smaller. (Station)                                                        	13 Destroyed if enemy ship present and no friendly ships
  Large  Starbase   (LSB) 	For bases BP400(H20) or smaller. (Fortress)                                                       	25 Destroyed if enemy ship present and no friendly ships

Warp Hull       	---- 	Allows a ship to move from star to star through space and to jump along Warplines.
 Sm Warp Gen (opt) 	(SWG) 	For ships BP  9(H 3) or smaller. (Escorts)                                                         	 3 - 1 PD makes 1MP
 Md Warp Gen (opt) 	(MWG) 	For ships BP 36(H 6) or smaller. (Cruisers)                                                        	 6 - 2 PD makes 1MP
 Lg Warp Gen (opt) 	(LWG) 	For ships BP 64(H 8) or smaller. (Capitals)                                                        	 9 - 3 PD makes 1MP
 Gt Warp Gen (opt) 	(GWG) 	For ships BP100(H10) or smaller. (Supercapitals)                                                   	12 - 3 PD makes 1MP
 
Systemship Hull  	---- 	Allows a ship to maneuver and attack within a star system.
 Sm Sys Ship (opt) 	(SSS) 	For ships BP  9(H 3) or smaller. (Fighters/Escorts)                                                  0 - 1 PD makes 1MP
 Md Sys Ship (opt) 	(MSS) 	For ships BP 36(H 6) or smaller. (Cruisers)                                                          2 - 2 PD makes 1MP
 Lg Sys Ship (opt) 	(LSS) 	For ships BP 64(H 8) or smaller. (Capitals)                                                          4 - 3 PD makes 1MP
 Gt Sys Ship (opt) 	(GSS) 	For ships BP100(H10) or smaller. (Supercapitals)                                                     6 - 3 PD makes 1MP
 #>

[cmdletBinding()]
param(
	#Game constants.
    $const_combat_max_rounds = 3
,	$const_hull_damage_value = 1 #0 for "vanilla" rules; 1+ makes larger ships tougher than smaller ships with equal armor/shields/ecm.
,	$const_TL_add_to_BPLimit = 1 #0 for "vanilla" rules; 1+ alters the BP-by-size calculation from the static max-size spec to (sqrt(MaxSize) * (sqrt(maxSize) + TL -1))
,	$const_TL_add_to_damage  = 0 #1 for "vanilla" rules; 0 compensates for the increased damage capability that comes from having more BP for higher-TL ships.
	
	#Initial Configuration.
,   $BPCostSpec             = "PD=1 B=1 S=1 T=1 M=1/3 SR=1 C=1 SH=1/6 A=1/2 E=1 H=1/10 R=5 CP=15 SSB=7 MSB=13 LSB=25 SWG=3 MWG=6 LWG=9 GWG=12 SSS=0 MSS=2 LSS=4 GSS=6"
,   $maxSizeSpec            = "SSB=64 MSB=144 LSB=400 SWG=9 MWG=36 LWG=64 GWG=100 SSS=9 MSS=36 LSS=64 GSS=100"
,   $pdPerMPSpec            = "SWG=1 MWG=2 LWG=3 GWG=3" # Other ship/station types cannot generate strategic movement.
,   $hullSpec               = "SSB=8 MSB=12 LSB=20 SWG=3 MWG=6 LWG=8 GWG=10 SSS=3 MSS=6 LSS=8 GSS=10"

    #Template and combatant warship specs                          
,   $templateInfoSpec       = "ID=TS1-01-001 Name=Template_Ship Owner=Template_Owner Location=COORD[-,-] TL=1 Universe=Reign_Of_Stars Valid=??? Racks= Cargo="
,   $templateAttrSpec       = "PD=0 B=0 S=0 T=0 M=0 SR=0 C=0 SH=0 A=0 E=0 H=0 R=0 CP=0 SWG=0 MWG=0 LWG=0 SB=0 _BPCost=0 _MaxSize=0 _PDPerMP=0 _Hull=0"
,   $templateSpec           = ("{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec)
,   $shipSpecs              = @(
                                 "{0} -- {1}" -f "ID=IWS-01-001 Name=Gladius_001 Owner=Empire Location=COORD[1,1] TL=2", "SWG=1 MWG=1 PD=4 B=2 S=1"
								,"{0} -- {1}" -f "ID=ISS-0A-00A Name=Portero_001 Owner=Empire Location=COORD[1,1] TL=1 Cargo=2xBP,Marine_Guards(5)", "SSS=1 PD=6 H=10 S=2" 
                                ,"{0} -- {1}" -f "ID=RWS-01-001 Name=Vulpine_001 Owner=Rebels Location=COORD[2,2] TL=2 Racks=RSS-0A-00A,RSB-0A-001,BOGUS", "SWG=1 PD=2 T=1 S=1 M=3 SR=1"
                                ,"{0} -- {1}" -f "ID=RSS-0A-00A Name=Kitsune_00A Owner=Rebels Location=Racked TL=2", "SSS=1 PD=5 B=4 S=1"
								,"{0} -- {1}" -f "ID=RSB-0A-001 Name=Warrens_00A Owner=Rebels Location=Racked", "SSB=1 PD=2 B=1 S=1"
							)
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
    Write-Host ( (WriteSummary -shipSet $shipObjects.Values) -replace "_", " " | Out-String)
	
	Write-Host "Begin combat!"
	1..$const_combat_max_rounds | foreach {
		Write-Host "Begin Round $_"
		$result = Evaluate-CombatRound -ships $shipObjects.Values
		Write-Verbose (WriteSummary -shipSet $shipObjects.Values | Out-String)
		Write-Verbose "End Round $_ - result code: $result"
		Write-Verbose ""
	}
	Write-Host "End combat!"
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
	
    $shipObjects = @{}

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
    $shipSpecs | foreach { 
		Write-Debug "`n`n"
		$newShip = loadShip -spec $_ -template $shipTemplate -myBPCostsLookup $BPCostsLookup -myMaxSizeLookup $maxSizeLookup -myPDPerMPLookup $pdPerMPLookup -myHullLookup $hullLookup; 
		$shipObjects.add($newShip.ID, $newShip); 
	}
	
	Write-Debug " - Replacing racked ship ID lists with racked ship references..."
	foreach($shipEntry in $shipObjects.GetEnumerator()) {
		$ship = $shipEntry.Value
		if($ship.Racks.Count -gt 0)
		{
			Write-Debug "    - $($ship.ID) has $($ship.Racks.Count) racked units"
			foreach ($rackSpot in 0..($ship.Racks.Count-1))
			{
				$rackedID              = $ship.Racks[$rackSpot]
				if( $shipObjects.containsKey($rackedID) )
				{
					$rackedUnit            = $shipObjects[$rackedID]
					$ship.Racks[$rackSpot] = $rackedUnit
					$rackedUnit.RackedBy   = $ship.ID
					$rackedUnit.Location   = $ship.Location
					
					Write-Debug "        - Replace $rackedID at position $rackSpot with $rackedUnit -- $($ship.Racks[$rackSpot].Name)"
				}
				else
				{
					Write-Debug "        - No match found for racked ID '$rackedID', $($ship.Name) has unusual cargo!"
				}
			}
		}
	}

	Write-Debug " - Validate all ship objects according to engine rules..."
	foreach ($shipEntry in $shipObjects.GetEnumerator()) {
		$ship = $shipEntry.Value
		$ship["validationNotes"] = validate-GameObject -Game-Object $ship
		if($ship.validationNotes -eq $null -or $ship.validationNotes.Count -eq 0) 
		     {$ship.Valid="true" } 
		else {$ship.Valid="false"}
	}
		
    Write-Debug ( "Init Complete! Initialized {0} ships" -f $shipObjects.Count)
    Write-Debug( WriteSummary -shipSet (@($shipTemplate)+$shipObjects.Values) -includeZeroes | Out-String )

	return $shipObjects
}

function validate-GameObject()
{
	[cmdletBinding()]
	param(
		[alias ("Game-Object")]
		$GO 
	)
	write-Verbose "     Validating $($GO.Name)"
		
	$GOa = $GO.attrs
	
	#Game-Object should only have one _MaxSize/_PDPerMP-defining component (*WG or SB or *SS)
	write-debug ("          Hull uniqueness? -- SWG:{0}, MWG:{1}, LWG:{2}, SB:{3}" -f $GOa.SWG, $GOa.MWG, $GOa.LWG, $GOa.SB)
	if($GOa.SWG + $GOa.MWG + $GOa.LWG + $GOa.SB -gt 1) { "Multiple WarpGen and/or SB components" }
	
	#_BPCost should be less than _MaxSize
	write-debug ("          _BPCost within threshold? -- _BPCost:{0}, _MaxSize:{1}" -f $GOa._BPCost, $GOa._MaxSize)
	if($GOa._BPCost -gt $GOa._MaxSize) { "BP Cost {0} Exceeds Maximum {1} for Hull/Drive Type" -f $GOa._BPCost, $GOa._MaxSize }
	
	#Attributes probably shouldn't be negative, excepting _PDPerMP for systemships and stations
	write-debug ("")
	if(($GOa.GetEnumerator() | ? { $_.Value -lt 0 -and $_.Key -ne "_PDPerMP" } | Measure-Object).Count -gt 0) {"One or more attrs are negative"}
	
	#Hangar space ( SR attr * _Hull attr )cannot be exceeded by hull sizes of attached units.
	write-debug ("          More racked hulls ({0}) than SR attribute ({1})?" -f $GO.Racks.Count, $GOa.SR)
	if($GOa.SR -lt $GO.Racks.Count) {"Hangar maximum ({0}) exceeded by attached units ({1})" -f $GOa.SR, $GO.Racks.Count}
	
	#Rack entries must map to IDs of other game-objects
	foreach ($racked in $GO.Racks)
	{
		if( $racked.GetType().Name -eq "aString".GetType().Name)
		{
			"Rack entry $racked is not a valid game object"
		}
	}
	
	#SR cannot accommodate a unit bigger than parent's _Hull
	write-debug ("          Ship carrying a bigger ship?")
	foreach ($racked in $GO.Racks)
	{
		write-debug ("               Host unit {0} vs racked unit {1}: Hull {2} vs {3}" -f $GO.ID, $racked.ID, $GOa._Hull, $racked.attrs._Hull)
		if($racked.attrs._Hull -gt $GOa._Hull)
		{
			("{0} hull size {1} is too small to hold {2} hull size {3} in its racks" -f $GO.ID, $GOa._Hull, $racked.ID, $racked.attrs._Hull)
		}
	}
	
	#Unit which is in racks cannot have ITSELF in its racks
	
	#Unit cannot be in more than one rack position at the same time
	
	#Unit cannot have more cargo than its H attribute
	
}


function loadShip($spec, $template, $myBPCostsLookup, $myMaxSizeLookup, $myPDPerMPLookup, $myHullLookup)
{
    $infoSpec, $attrSpec = ($spec -split " -- ")
    Write-Debug "  Load Ship Info..."
    $ship                    = HashFromSpec -hashSpec $infoSpec
	Write-Debug "  Load Ship Attributes..."
    $ship["attrs"]           = HashFromSpec -hashSpec $attrSpec -numeric
	$ship["validationNotes"] = @()

    Write-Debug "  Post-Process..."
    Write-Debug "  -- Instantiate all templated values not overridden by spec"
      if($template -ne $null) { $template.GetEnumerator() | ? {$_.Key -ne "attrs" } | % { if (-not $ship.ContainsKey($_.Key)) {$ship.add($_.Key, $_.Value) } } }
      if($template -ne $null) { $template.attrs.GetEnumerator() | % { if (-not $ship.attrs.ContainsKey($_.Key)) {$ship.attrs.add($_.Key, $_.Value) } } }
    Write-Debug "  -- Calculate BP cost based on cost spec and unit attributes"
	  $ship.attrs._BPCost  = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec $myBPCostsLookup)  | measure-object -sum).sum
    Write-Debug "  -- Calculate _MaxSize attr for $ship.Name based on maxSizeSpec and SWG/MWG/LWG/SB allocation $myMaxSizeLookup"
	$ship.attrs._MaxSize = calculate-MaxSize -ship $ship -lookup $myMaxSizeLookup
    Write-Debug "  -- Calculate _PDPerMP attr for $ship.Name based on pdPerMPSpec and SWG/MWG/LWG/SB allocation $myPDPerMPLookup"
	  $ship.attrs._PDPerMP = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec  $myPDPerMPLookup) | measure-object -maximum).maximum  
    Write-Debug "  -- Calculate _Hull based on hullSpec and S*/M*/L*/H*/SB allocation, PD, SR, CP, A, ..."
	  $ship.attrs._Hull    = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec  $myHullLookup)    | measure-object -sum).sum
	Write-Debug "  -- Instantiate Rack content ID list ['$($ship.Racks)']"
	  $ship.Racks          = if([string]$ship.Racks -eq "") { @() } else { $ship.Racks -split "," }
	Write-Debug "  -- Found $($ship.Racks.Count) ships in racks -- '$($ship.Racks)'"
	Write-Debug "  -- Instantiate Cargo content list ['$($ship.Cargo)']"
	  $ship.Cargo          = if([string]$ship.Cargo -eq "") { @() } else { $ship.Cargo -split "," }
	  $ship.Cargo          = Convert-CargoToList -CargoItems $ship.Cargo
	  $ship.attrs.HUsed    = Calculate-CargoSum  -CargoItems $ship.Cargo
	Write-Debug "  -- Found $($ship.Cargo.Count) cargo entries -- '$($ship.Cargo)'"
	
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
		write-Debug ("{0} = {1}" -f $myKey, $myVal)
        if($numeric) { $myVal=Invoke-Expression $myVal }
        else         { $myVal=$myVal.Trim() }
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

function calculate-MaxSize()
{
	[cmdletBinding()]
	param (
		[HashTable] $ship
	,   [HashTable] $lookup
	)
	$mS = ( (get-DerivedValueSet -attrSet $ship.attrs -depSpec  $lookup) | measure-object -maximum).maximum
	
	 #MaxSize is simple for "vanilla" rules; Optional TL rule alters the BP-by-size calculation 
	 #  from the static max-size spec 
	 #  to (sqrt(MaxSize) * (sqrt(maxSize) + TL -1))
	if($const_TL_add_to_BPLimit -gt 0)
	{
		[math]::sqrt($mS) * ([math]::sqrt($mS) + $ship.TL -1)
	}
	else
	{
		$mS
	}
}

function convert-CargoToList()
{
	[cmdletBinding()]
	param(
		$cargoItems
	)
	
	$stupidRegex = "((?<qty>\d*)\s*x\s*)?(?<item>\w*)(\s*\(\s*(?<size>\d*)\s*\))?"
	
	Write-Debug "CONVERT CARGO"
	$cargoList = @()
	foreach ($cI in $cargoItems) {
		Write-Debug "     CARGO $cI"
		$result = $cI -match $stupidRegex; 		
		if($result -eq $true)
		{
			$cH = @{}
			$cH.Item = ($($matches["item"]), "???" -ne $null)[0]
			$cH.Size = ($($matches["size"]), "1"   -ne $null)[0]
			$cH.Qty  = ($($matches["qty"]) , "1"   -ne $null)[0]
			
			write-Debug "         Item : ""$($cH.Item)"""
			write-Debug "         Size : ""$($cH.Size)"""
			write-Debug "         Qty  : ""$($cH.Qty )"""
			
			$cargoList += $cH
		}
		else
		{
			Write-Debug "         REGEX no match for $cI"
		}
	}
	$cargoList
}

function calculate-CargoSum()
{
	[cmdletBinding()]
	param(
		$cargoItems
	)
	
	Write-Debug "SUM CARGO"
	$cargoSum = 0
	foreach ($cI in $cargoItems) {
		$cIItem = $cI.Item
		$cIQty  = [Decimal] $cI.Qty
		$cISize = [Decimal] $cI.Size

		Write-Debug "     CARGO $cIItem - $cIQty x $cISize"
		if($cIQty -gt 0 -and $cISize -gt 0)
		{
			$cargoSum += $cIQty * $cISize
		}
		else
		{
			Write-Debug "         Qty or Size for $cIItem invalid"
		}
	}
	$cargoSum
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
	
	#Excluded info fields -- fields which either need additional special handling, 
	$exclInfoFields = ("attrs", "validationNotes", "Cargo", "Valid", "Racks")
	#Ordered info fields
	$orderedInfoFields = ("ID", "Name", "Owner", "Universe") 
	$orderedInfoFields | % { "{0,-15} | {1}" -f $_, $s["$_"] }
	#Unordered info fields - just display alphabetically
    $s.GetEnumerator() | sort name | foreach { 
		if(-not $orderedInfoFields.Contains($_.Key) -and -not $exclInfoFields.Contains($_.Key)) { 
			"{0,-15} | {1}" -f $_.Key, $_.Value 
		} 
	} 
	#Complex fields
	""
    $AttrSummary  = "| "
	$s.attrs.GetEnumerator() | sort name | ? { ($_.Value -ne 0) -or $includeZeroes -eq $true } | % { $AttrSummary += ("{0,-12}:{1,11} |`n{2} | " -f $_.Key, $_.Value, (" "*15))  }
	$AttrSummary += ("-"*24)+" |"
    "{0,-16}| {1} |`n{2}{3}" -f "Attributes", ("-"*24), (" " * 16), $AttrSummary
	if($s.Racks.Count -gt 0 -or $includeZeroes)
	{ 
		$RackSummary  = ""
		$RackSummary += if($s.Racks.Count -gt 0){ "| " } else{ "" }
		if($s.Racks.Count -gt 0) { $s.Racks | % { ($_.ID, $_ -ne $null )[0] } | % { $RackSummary += ("{0, -24} |`n{1} | " -f $_, (" "*15)) } }
		$RackSummary += "| "+("-"*24)+" |"
		""
		"{0,-16}| {1} |`n{2}{3}" -f "Racks", ("-"*24), (" " * 16), $RackSummary.replace("| | ", "| ")
	}
	if($s.Cargo.Count -gt 0 -or $includeZeroes)
	{ 
		$CargoSummary  = ""
		$CargoSummary += if($s.Cargo.Count -gt 0){ "| " } else{ "" }
		if($s.Cargo.Count -gt 0) 
		{ 
			foreach ($cI in $s.Cargo)
			{ 
				$itemTxtRuler = "-"*10
				$itemTxt = $cI.Item
				if($itemTxt.length -gt $itemTxtRuler.length)
				{
					$itemTxt = $itemTxt.substring(0, $itemTxtRuler.length)+"..."
				}
				$lineEntry = "{0,3} x {1,-13} ({2,2})" -f $cI.Qty, $itemTxt, $cI.Size
				$CargoSummary += ("{0, -24} |`n{1} | " -f $lineEntry, (" "*15))
			}
		$CargoSummary += "| "+("-"*24)+" |"
		""
		"{0,-16}| {1} |`n{2}{3}" -f ("Cargo({0}/{1})" -f $s.attrs.HUsed, $s.attrs.H), ("-"*24), (" " * 16), $CargoSummary.replace("| | ", "| ")
		}
	}
	
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

