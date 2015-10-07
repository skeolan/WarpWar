function init()
{						
	[cmdletBinding()]
	param(
		$cfg
	)
	Add-Type -AssemblyName System.Web.Extensions
	$GameData  = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Deserialize($cfg, [System.Collections.Hashtable])
	$Constants = $GameData.Constants
	
	Init-ShipsFromTemplate -template $GameData.ShipTemplate -componentSpec $GameData.ComponentSpecs -shipSpec $GameData.ShipSpecs
	Init-ShipCollections   -template $GameData.ShipTemplate -componentSpec $GameData.ComponentSpecs -shipSpec $GameData.ShipSpecs -systems $GameData.Systems
	Init-UnitMethods       -units    $GameData.ShipSpecs
	
	$GameData	
}

function execute-TurnOrder()
{
	[cmdletBinding()]
	param (
		  $attacker
		, $defender
		, $attackerOrders
		, $defenderOrders
	)
	
	$a  = $attacker
	$d  = $defender
	$ao = $attackerOrders
	$do = $defenderOrders
	
	write-verbose ( "[ENGINE:Execute-TurnOrder] {0} attacks {1}!" -f $a.Name, $d.Name )
	write-verbose ( "[ENGINE:Execute-TurnOrder]     Orders: {0} : {1} at Drive {2} vs {3} : {4} at Drive {5}" -f $a.Name, $ao.Tactic, $ao.PowerAllocation.PD, $d.Name, $do.Tactic, $do.PowerAllocation.PD)
	
	if((Validate-Orders($attacker, $defender, $attackerOrders, $defenderOrders)) -eq $false) { return $false }
	
	#component data structures useful for adjudicating results
	$weps = $GameData.ComponentSpecs | ? { $_.CompType -eq "Weapon"     } # or $_.RoF -ne $null if you want to be fancy
	$ammo = $GameData.ComponentSpecs | ? { $_.CompType -eq "Ammunition" }
	$defs = $GameData.ComponentSpecs | ? { $_.CompType -eq "Defense"    }
	$hull = $GameData.ComponentSpecs | ? { $_.CompType -eq "Hull"       }
	$bays = $GameData.ComponentSpecs | ? { $_.CompType -eq "Carry"      }
	$util = $GameData.ComponentSpecs | ? { $_.CompType -eq "Utility" -or $_.CompType -eq  "Power" }
	
	$aDrive       = $ao.PowerAllocation.PD
	$dDrive       = $do.PowerAllocation.PD
	$aTL          = $attacker.TL
	$dTL          = $defender.TL

	$targetDamage = 0
	$turnResult   = "Continue"
	
	foreach ($weapon in ($weps + $ammo))
	{
		$wepOrderedPwr = nullCoalesce ($ao.PowerAllocation.$($weapon.Name), 0)
		$wepName       = $weapon.Name		
		
		#Direct-fire weapons, e.g. Beams and Shells (presuming Cannons were activated, as confirmed in Validate-Orders)
		if($weapon.Damage -gt 0 -and $wepOrderedPwr -gt 0)
		{
			$wepOrderedDrive  = nullCoalesce((Get-OrderedWeaponDrive $ao $wepName), $aDrive)
			write-verbose ( "{0}Evaluate attack for {1}, allocated {2} power, drive {3} vs defender {4}" -f "[ENGINE:Execute-TurnOrder]     ", $wepName, $wepOrderedPwr, $wepOrderedDrive, $aDrive )
			$wepResult = Calculate-CombatResult $ao.Tactic $do.Tactic $aDrive $dDrive
			if($wepResult -ne "Miss" -and $wepResult -ne "Escapes")
			{
				$wepOrderedDamage = Calculate-WeaponDamage $wepName $wepOrderedPwr $wepOrderedDrive $dDrive $aTL $dTL $ao $do $wepResult 
				if($wepOrderedDamage -ne 0)
				{
					write-verbose ( "{0}Target hit for {1} damage!" -f "[ENGINE:Execute-TurnOrder]     ", $wepOrderedDamage)
				}
			}
			if($wepResult -eq "Miss")
			{
				write-verbose ("{0} {1} attack with {2} missed {3} !" -f "[ENGINE:Execute-TurnOrder]     ", $attacker.Name, $wepName, $defender.Name)
			}
			
			if($wepResult -eq "Escapes")
			{
				write-verbose ("{0} {1} attack with {2} missed and permitted {3} to escape!" -f "[ENGINE:Execute-TurnOrder]     ", $attacker.Name, $wepName, $defender.Name)
				$turnResult="Escapes"
			}
		}
	}
	write-verbose ( "[ENGINE:Execute-TurnOrder] Result: {0}" -f $turnResult )
	$turnResult
}

function init-ShipsFromTemplate()
{
	[cmdletBinding()]
	param ( 
		  $template
		, $componentSpec
		, $shipSpecs
	)
	
	$shipT = $template
	$ships = $shipSpecs
	$cs = $componentSpec

	#Convert template's Components and PowerAllocation dictionaries into KeyValuePair arrays for consistency
	$shipT.Components      = $shipT.Components.GetEnumerator()      | ? { $_.Value -ne $null }
	$shipT.PowerAllocation = $shipT.PowerAllocation.GetEnumerator() | ? { $_.Value -ne $null }


	
	foreach ($ship in $ships)
	{
		foreach ($tProperty in $shipT.Keys)
		{ 
			$propName = $tProperty
			$propVal  = $shipT.$propName
			
			if($ship.$tProperty -eq $null) 
			{
				$ship.$propName = $propVal
			} 
		}
	}
}

function init-ShipCollections
{
	[cmdletBinding()]
	param ( 
		  $template
		, $componentSpec
		, $shipSpecs
		, $systems
	)
	
	
	#First pass -- does not depend on other units' derived values
	foreach ($ship in $shipSpecs)
	{
		write-verbose " - Filter out zero-value components and power allocations"
		$ship.Components      = $ship.Components.GetEnumerator()      | ? { $_.Value -ne 0 }
		$ship.PowerAllocation = $ship.PowerAllocation.GetEnumerator() | ? { $_.Value -ne 0 }

		
		write-verbose " - Filter out irrelevant damage values"
		$ship.Damage     = remove-ExtraProperties   -parent $ship.Components -child $ship.Damage
		
		write-verbose "Replace reference IDs in e.g. 'Racks' and 'Cargo' arrays with references to Ships"
		$ship.Cargo      = replace-IDsWithReferences -collection $ship.Cargo -referenceCollection $shipSpecs
		$ship.Racks      = replace-IDsWithReferences -collection $ship.Racks -referenceCollection $shipSpecs

		write-verbose "Replace location IDs for $($ship.Name) in 'Location' property '$($ship.Location)' with references to Systems OR, failing that, Ships"
		$ship.Location   = (replace-IDsWithReferences -collection $ship.Location -referenceCollection @($systems + $shipSpecs))
		write-verbose "Location is now $($ship.Location)"
		
		write-verbose "Generate effective attribute values from components, damage"
		$ship.EffectiveAttrs   = (generate-effectiveAttrs -unit $ship -components $componentSpec)

		write-verbose "Generate derived attributes from components, racks, cargo"
		generate-derivedAttrs -unit $ship -componentSpec $componentSpec

		write-verbose "Generate validation errors from components, racks, cargo, damage"
		$ship.ValidationResult = (Validate-Unit -unit $ship)
			
	}
	#Second pass -- depends on other units' derived values
	foreach ($ship in $shipSpecs)
	{
		write-verbose "Generate derived attributes from unit collections"
		generate-collectionAttrs -unit $ship -componentSpec $componentSpec
	}

}

function init-UnitMethods()
{
	[cmdletBinding()]
	param(
		$units
		
	)

}

function generate-derivedAttrs()
{
	[cmdletBinding()]
	param (
		  $unit
		, $componentSpec
	)

	#Total construction cost
	$unit.BPCost   = ( (get-DerivedValueSet -depKey "BPCost" -attrSet $unit.Components -depSpec $componentSpec )  | measure-object -sum).sum

	#Total Power Allocation
	$unit.PowerUsed = (nullCoalesce ( $unit.PowerAllocation  | measure-object -property Value -sum).sum,  0 )

	#Hull/drivetype dependent
	$unit.PDPerMP  = ( (get-DerivedValueSet -depKey "PDPerMP" -attrSet $unit.Components -depSpec $componentSpec )  | measure-object -sum).sum	
	$unit.Size     = ( (get-DerivedValueSet -depKey "Hull" -attrSet $unit.Components -depSpec $componentSpec )  | measure-object -sum).sum	
	$unit.BPMax    = ( (get-DerivedValueSet -depKey "MaxSize" -attrSet $unit.Components -depSpec $componentSpec )  | measure-object -sum).sum
	$unit.MP       = calculate-MovementPoints -drive (get-ComponentValue -unit $unit -componentKey "PD") -efficiency $unit.PDPerMP

	#BPMax is simple for "vanilla" rules; Optional TL rule alters the BP-by-size calculation 
	#  from the static max-size spec 
	#  to (sqrt(BPMax) * (sqrt(BPMax) + TL -1))
	if($Constants.TL_addTo_BPLimit -gt 0)
	{
		$mS           = $unit.BPMax
		write-verbose "Vanilla BPMax is $($unit.BPMax)"
		$unit.BPMax = [Math]::sqrt($mS) * ([Math]::sqrt($mS) + $ship.TL -1)
		write-verbose "...but TL-adjusted BPMax is $($unit.BPMax)"
	}
}

function generate-collectionAttrs()
{
	[cmdletBinding()]
	param(
		  $unit
		, $componentSpec
	)
	#Cargo/racks
	$unit.HUsed     = calculate-ContainerSum -container $unit.Cargo 
	$unit.HAvail    = ($unit.EffectiveAttrs.H) * ($componentSpec | ? { $_.Name -eq "H" } ).Cargo
	$unit.SRUsed    = $unit.Racks.Count
	$unit.SRAvail   = $unit.EffectiveAttrs.SR
		
}

function generate-effectiveAttrs()
{
	[cmdletBinding()]
	param (
		  $unit
		, $componentSpec
	)
	$result = @{}
	
	#For each nonzero Component, subtract Damage value from Component value
	foreach ($c in $unit.Components.GetEnumerator())
	{
		$cKey           = $c.Key
		$cVal           = $c.Value
		$cSpec          = $componentSpec | ? { $_.Name -eq $cKey }
		
		
		if($cSpec.Hull -gt 0)
		{
			$cVal = $cSpec.Hull * $c.Value
		}
		
		$dmgVal         = ($unit.Damage.$cKey)+0
		$effectiveValue = ($cVal - $dmgVal)
		$result.$cKey   = $effectiveValue
		
		write-verbose ("{0} spec value is {1}, damage value is {2} -- effective value is {3}" -f $cKey, $cVal, $dmgVal, $effectiveValue )
	}

	$result
}

function Validate-Orders()
{
	[CmdletBinding()]
	param(
		  $attacker
		, $defender
		, $attackerOrders
		, $defenderOrders		
	)

	$true
}

function Get-OrderedWeaponDrive()
{
	[CmdletBinding()]
	param(
		  $orders
		, $weaponName
	)
	write-verbose "[ENGINE:Get-OrderedWeaponDrive]      Find unresolved attacker drive orders for weapon $weaponName"
	$null
}

function Calculate-CombatResult()
{
 [CmdletBinding()]
 param(
	  $aTac
	, $dTac
	, $aDrive
	, $dDrive
	)
	
	$driveDiff  = $aDrive - $dDrive
	if( $driveDiff -gt  5 ) { $driveDiff= 5 }
	if( $driveDiff -lt -5 ) { $driveDiff=-5 }
	
	$tacPairing = "{0}:{1}" -f $aTac, $dTac

	#AttackerTactic.DefenderTactic[DriveDiff]
						  #(   -5          -4          -3         -2          -1          0           1             2          3          4           5      )
	$CombatResults = @{
		"Attack"  = @{
		 	  "Attack"  = @("Miss"    , "Miss"    , "Miss"    , "Hit"     , "Hit"     , "Hit+2"   , "Hit+2"   , "Hit+1"   , "Miss"    , "Miss"    , "Miss"   )
			; "Dodge"   = @("Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Hit+1"   , "Hit"     , "Hit"     , "Miss"   )
			; "Retreat" = @("Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Miss"    , "Miss"    , "Miss"    , "Hit"     , "Hit"     , "Miss"   )
		}                                                                                                                                                    
		; "Dodge"   = @{                                                                                                                                     
			  "Attack"  = @("Miss"    , "Miss"    , "Miss"    , "Miss"    , "Hit"     , "Hit"     , "Hit"     , "Hit"     , "Miss"    , "Miss"    , "Miss"   )
		    ; "Dodge"   = @("Miss"    , "Miss"    , "Hit"     , "Hit"     , "Hit"     , "Hit"     , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"   )
		    ; "Retreat" = @("Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" ,"Escapes" )
		}
		; "Retreat" = @{
			  "Attack"  = @("Miss"    , "Miss"    , "Miss"    , "Miss"    , "Hit"     , "Hit"     , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"   )
		    ; "Dodge"   = @("Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"    , "Miss"   )
		    ; "Retreat" = @("Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" , "Escapes" ,"Escapes" )
		}
	
	}
	
	switch($tacPairing)
	{
	Attack:Attack   { 
						switch($driveDiff)
						{
							-5 { $result="Miss" ; break; }
							-4 { $result="Miss" ; break; }
							-3 { $result="Miss" ; break; }
							-2 { $result="Hit"  ; break; }
							-1 { $result="Hit"  ; break; }
							 0 { $result="Hit+2"; break; }
							 1 { $result="Hit+2"; break; }
							 2 { $result="Hit+1"; break; }
							 3 { $result="Miss" ; break; }
							 4 { $result="Miss" ; break; }
							 5 { $result="Miss" ; break; }
						}
						break; 
					}
	Attack:Dodge    { 
						switch($driveDiff)
						{
							-5 { $result="Miss"  ; break; }
							-4 { $result="Miss"  ; break; }
							-3 { $result="Miss"  ; break; }
							-2 { $result="Miss"  ; break; }
							-1 { $result="Miss"  ; break; }
							 0 { $result="Miss"  ; break; }
							 1 { $result="Miss"  ; break; }
							 2 { $result="Hit+1" ; break; }
							 3 { $result="Hit"   ; break; }
							 4 { $result="Hit"   ; break; }
							 5 { $result="Miss"  ; break; }
						}
						break; 
					}
	Attack:Retreat  { 
						switch($driveDiff)
						{
							-5 { $result="Escapes" ; break; }
							-4 { $result="Escapes" ; break; }
							-3 { $result="Escapes" ; break; }
							-2 { $result="Escapes" ; break; }
							-1 { $result="Escapes" ; break; }
							 0 { $result="Miss"    ; break; }
							 1 { $result="Miss"    ; break; }
							 2 { $result="Miss"    ; break; }
							 3 { $result="Hit"     ; break; }
							 4 { $result="Hit"     ; break; }
							 5 { $result="Miss"    ; break; }
						}
						break; 
					}
	Dodge:Attack    { 
						switch($driveDiff)
						{
							-5 { $result="Miss" ; break; }
							-4 { $result="Miss" ; break; }
							-3 { $result="Miss" ; break; }
							-2 { $result="Miss" ; break; }
							-1 { $result="Hit"  ; break; }
							 0 { $result="Hit"  ; break; }
							 1 { $result="Hit"  ; break; }
							 2 { $result="Hit"  ; break; }
							 3 { $result="Miss" ; break; }
							 4 { $result="Miss" ; break; }
							 5 { $result="Miss" ; break; }
						}
						break; 
					}
	Dodge:Dodge     { 
						switch($driveDiff)
						{
							-5 { $result="Miss" ; break; }
							-4 { $result="Miss" ; break; }
							-3 { $result="Hit"  ; break; }
							-2 { $result="Hit"  ; break; }
							-1 { $result="Hit"  ; break; }
							 0 { $result="Hit"  ; break; }
							 1 { $result="Miss" ; break; }
							 2 { $result="Miss" ; break; }
							 3 { $result="Miss" ; break; }
							 4 { $result="Miss" ; break; }
							 5 { $result="Miss" ; break; }
						}
						break; 
					}
	Dodge:Retreat   { 
						$result = "Escapes"
						break; 
					}
	Retreat:Attack  { 
						switch($driveDiff)
						{
							-5 { $result="Miss" ; break; }
							-4 { $result="Miss" ; break; }
							-3 { $result="Miss" ; break; }
							-2 { $result="Miss" ; break; }
							-1 { $result="Hit"  ; break; }
							 0 { $result="Hit"  ; break; }
							 1 { $result="Miss" ; break; }
							 2 { $result="Miss" ; break; }
							 3 { $result="Miss" ; break; }
							 4 { $result="Miss" ; break; }
							 5 { $result="Miss" ; break; }
						}
						break; 
					}
	Retreat:Dodge   { 
						$result="Miss"
						break; 
					}
	Retreat:Retreat { 
						$result="Escapes"
						break; 
					}
	Default         { 
						$result = "INVALID"; 
						break; 
					}
	}
	
	write-verbose "[ENGINE:Calculate-CombatResult]      $tacPairing at $driveDiff => $result"
	write-verbose("[ENGINE:Calculate-CombatResult]        -- Using hash-array CRT method: {0}" -f $CombatResults.$aTac.$dTac[($driveDiff+5)])
	
	$result
}

function Calculate-WeaponDamage()
{
[CmdletBinding()]
	param(
		    $wepName
		  , $wepOrderedPwr
		  , $aDrive
		  , $dDrive
		  , $aTL
		  , $dTL
		  , $ao
		  , $do
		  , $result
	)
	
	$weaponDamage = 0
	
	$weaponResult = Calculate-CombatResult $ao.Tactic $do.Tactic $aDrive $dDrive
	
	
	#$weaponDamage
	-99
}

function Validate-Unit()
{
	[cmdletBinding()]
	param (
		$unit
	)
	
	$result = @()
	
	#SRUsed - SRAvail should be nonnegative
	#HUsed  - HAvail  should be nonnegative
	#BPMax  - BPCost  should be nonnegative
	
	#EffectiveAttrs should each be nonnegative
	
	#Units in your Racks should have Size no larger than you
	#Units in your Racks should have you as their Location
	#Units in your Racks should have no units in their Racks
	
	#Units in your Cargo should have no units in their Racks

	$result
}

function remove-ExtraProperties()
{
	[cmdletBinding()]
	param (
		  $parent #Collection whose list of properties is "canonical"
		, $child  #Collection should not contain any properties absent from parent
	)
	
		$collectionKeys  = $parent.Key
		$childVals = @{}
		foreach ($cKey in $collectionKeys)
		{
			$cVal = (nullCoalesce $child.$cKey, 0)
			$childVals.$cKey = $cVal
			$logText = "     {0,-10}" -f "$cKey : $cVal added to child collection"
			write-debug $logText
		}
		$childVals
}

function get-DerivedValueSet()
{
	[cmdletBinding()]
	param(
		 $attrSet, 
		 $depSpec,
		 $depKey
	)
	
	write-verbose "Deriving values for $depKey"
	
	if ($depSpec -eq $null) {
		Write-Debug "get-derivedValueSet call made with a null lookup table, will return -1" 
		return -1
	}
	
	$attrLookup = @{}

	foreach ($item in $attrSet)
	{
		$iKey = $item.Key
		$iVal = $item.Value
		$attrLookup.$iKey = $iVal
	}
		
	# Only nonzero attributes matter, AND only evaluate if lookup array is non-null
	foreach ($specEntry in $depSpec)
	{
		$entryName = $specEntry.Name
		$valueEach = $specEntry.$depKey
		$qty       = (nullCoalesce $attrLookup.$entryName, 0)
		write-debug "Get derived $depKey value for $entryName : $valueEach * $qty"
		if($qty -ne 0)
		{
			$resultValue = [Math]::Ceiling($valueEach * $qty)
			$resultValue
			write-verbose "$EntryName of $qty @$valueEach (rounded up)= $resultValue"
		}
	}
}

function calculate-ContainerSum()
{
	[cmdletBinding()]
	param(
		  $container
		, $cNameKey="Name"
		, $cQtyKey ="Qty"
		, $cSizeKey="Size"
	)
	
	$cSum = 0
	foreach ($cI in $container) {
		$cIItem = $cI.$cNameKey
		$cIQty  = [Decimal] (nullCoalesce $cI.$cQtyKey , 1)
		$cISize = [Decimal] (nullCoalesce $cI.$cSizeKey, 1)

		Write-Debug "     CONTAINER $cIItem - $cIQty x $cISize"
		if($cIQty -gt 0 -and $cISize -gt 0)
		{
			$cSum += $cIQty * $cISize
		}
		else
		{
			Write-Debug "         Qty or Size for $cIItem invalid"
		}
	}
	$cSum
}

function calculate-MovementPoints()
{
	[cmdletBinding()]
	param(
		  $drive
		, $efficiency
	)
	
	if ($efficiency -eq 0)
	{
		0
	}
	else
	{
		[Math]::floor($drive / $efficiency)
	}
}

function replace-IDsWithReferences()
{
	[cmdletBinding()]
	param (
		  $collection
		, $referenceCollection
	)
	
	$newCollection = @()
	
	foreach($item in $collection)
	{
		if($item.GetType().Name -like "string".GetType().Name)
		{
			$newEntry = $referenceCollection | where { $_.ID -eq $item }
			
			if ($newEntry -eq $null)
			{
				write-verbose "   String Collection item '$item' is not a reference to items in the indicated collection, leaving value as $item"
				$newCollection += $item
			}
			else
			{
				write-verbose "   Matched $item to $($newEntry.Name)"
				$newCollection += $newEntry
			}
		}
		else
		{
			write-verbose "  $item is not a string ID reference, so adding it as-is"
			$newCollection += $item
		}
	}
	
	$newCollection
}



function summarize-ComponentData()
{
	[cmdletBinding()]
	param( $compData )

	$weps = $GameData.ComponentSpecs | ? { $_.CompType -eq "Weapon"     } # or $_.RoF -ne $null if you want to be fancy
	$ammo = $GameData.ComponentSpecs | ? { $_.CompType -eq "Ammunition" }
	$defs = $GameData.ComponentSpecs | ? { $_.CompType -eq "Defense"    }
	$hull = $GameData.ComponentSpecs | ? { $_.CompType -eq "Hull"       }
	$bays = $GameData.ComponentSpecs | ? { $_.CompType -eq "Carry"      }
	$util = $GameData.ComponentSpecs | ? { $_.CompType -eq "Utility" -or $_.CompType -eq  "Power" }

	foreach ($item in @($util + $weps + $ammo + $defs + $hull + $bays))
	{
		$itemH = new-object PSCustomObject
		foreach ($key in $item.Keys)
		{
			if($key -eq "Info") { continue }
			$itemH | add-member -type NoteProperty -name $key -value $item.$key
		}
		foreach ($key in $item.Info.Keys)
		{
			$itemH | add-member -type NoteProperty -name "Info:$key" -value $item.Info.$key
		}
		$itemH
	}
}

function printShipInfo
{
    [cmdletBinding()]
	param(
		  $s
		, [switch] $includeZeroes
		, [Decimal] $infoEntryLeftSegmentLen  =20
		, [Decimal] $lineEntryLeftSegmentLen  =19
		, [Decimal] $lineEntryRightSegmentLen =25
		, [Decimal] $lineEntryFullLen         =45
	) 
	
	if($includeZeroes -eq $true)
	{
		WRITE-DEBUG ("{0}{1} -- including zeroes!" -f $s.Name, $s.ID )
	}
	else
	{
		WRITE-DEBUG ("{0}{1} -- EXcluding zeroes" -f $s.Name, $s.ID )
	}
	
	
	#Header
	("| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen} |" -f $s.ID, $s.Name )
	"|-{0,-$infoEntryLeftSegmentLen}--{1, -$lineEntryFullLen}-|" -f (("-"*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))
	#Excluded info fields -- fields which either need additional special handling, or aren't to be displayed
	$exclInfoFields = ("ID", "Name", "Cargo", "Components", "Damage", "DerivedAttrs", "EffectiveAttrs", "HAvail", "HUsed", "MP", "PDPerMP", "SRAvail", "SRUsed", "Location", "TurnOrders", "PowerAllocation", "PowerUsed", "Racks", "Valid", "ValidationResult")
	#Ordered info fields
	$orderedInfoFields = ("Owner", "Universe", "TL", "BPCost", "BPMax", "Size", "MP") 
	foreach ($infoKey in $orderedInfoFields)
	{ 
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen} |" -f ($infoKey, (nullCoalesce $s.$infoKey, 0))
	}
	
	#Unordered info fields - just display alphabetically
    $s.GetEnumerator() | sort key | foreach { 
		if(-not $orderedInfoFields.Contains($_.Key) -and -not $exclInfoFields.Contains($_.Key) -and ( $includeZeroes -eq $true -or $_.Value -ne 0) ) 
		{ 
			"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen} |" -f $_.Key, $_.Value 
		} 
	}
	
	#Complex info fields
		write-debug "Location"
		print-LocationDetail  -title "Location"   -location $s.Location

		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen}-|" -f ((" "*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))

		write-debug "Components"
		print-ComponentDetail -title "Components" -collection $s.Components -effectiveCollection $s.EffectiveAttrs -damageCollection $s.Damage -powerCollection $s.PowerAllocation -includeZeroes $includeZeroes 
		write-debug "Cargo"
		print-ListDetail      -title "Cargo"      -collection $s.Cargo -count $s.HUsed  -capacity $s.HAvail
		write-debug "Racks"		
		print-ListDetail      -title "Racks"      -collection $s.Racks -count $s.SRUsed -capacity $s.SRAvail
		write-debug "EffectiveAttrs (incl damage annotations)"
		write-debug "ValidationResult (incl 'Valid' ruling)"
		
	#Footer
	"|-{0,-$infoEntryLeftSegmentLen}--{1, -$lineEntryFullLen}-|" -f (("-"*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))
}

function print-ComponentDetail()
{
	[CmdletBinding()]
	param(
		  $collection
		, $damageCollection         = $null
		, $effectiveCollection      = $null
		, $powerCollection          = $null
		, $title                    = "Components"
		, $includeZeroes            = $false
		, $infoEntryLeftSegmentLen  = 20
		, $lineEntryLeftSegmentLen  = 19
		, $lineEntryRightSegmentLen = 25
		, $lineEntryFullLen         = 45
	)
	
	$compInfoHeader="Max | Dmg | Eff | Pwr "		

	if($collection.Count -gt 0 -or $includeZeroes)
	{
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen } {2, -$lineEntryRightSegmentLen} |" -f "$title", "Name (#)", $compInfoHeader
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen}-|" -f ((" "*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))

	}
	
	foreach ($entry in $collection)
	{
		write-debug $entry
		if($entry.Value -eq 0 -and -not $includeZeroes)
		{
			write-debug "$($entry.Key) is zero, skipping)"
			continue
		}
		
		if($entry.Value -ne $null)
		{
			$eKey         = $entry.Key
			$eVal         = $entry.Value
			$eDmgTxt      = (nullCoalesce $damageCollection.$eKey   , 0)
			$eEffTxt      = (nullCoalesce $effectiveCollection.$eKey, ($eVal - $eDmgTxt))
			$eSpecTxt     = $eEffTxt + $eDmgTxt
			$ePwrTxt      = (nullCoalesce ($powerCollection | ? { $_.Key -eq "$eKey" }).Value, 0)
			$eRightBuffer = $lineEntryRightSegmentLen - $compInfoHeader.Length
			
			if($eVal -ne 1)
			{
				$eKeyTxt = "{0,-4} ({1})" -f $eKey, $eVal
			}
			else
			{
				$eKeyTxt = $eKey
			}
			
			"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen} {2, 3} | {3, 3} | {4,3} | {5,3} {6,$eRightBuffer} |" -f "", $eKeyTxt, $eSpecTxt, $eDmgTxt, $eEffTxt, $ePwrTxt, ""
		}
	}
	
}

function print-LocationDetail()
{
	[CmdletBinding()]
	param(
		  $location
		, $title
		, $infoEntryLeftSegmentLen  = 20
		, $lineEntryLeftSegmentLen  = 19
		, $lineEntryRightSegmentLen = 25
		, $lineEntryFullLen         = 45
	)

	if($location -ne $null -or $includeZeroes)
	{
		$lineItemTitle = ""
		$lineItemInfo  = ""
		
		#Valid Possibilities: a) unit has a bare X,Y coordinate or System as its Location
		#                     b) unit is in Racks or Cargo - its parent is of type (a)
		#                     c) unit is in Cargo - its parent is in Racks, and ITS parent is of Type (a)
		#                     d) ???
		$xCoord = (nullCoalesce($location.X, $location.Location.X, $location.Location.Location.X, "?"))
		$yCoord = (nullCoalesce($location.Y, $location.Location.Y, $location.Location.Location.Y, "?"))

		$lineItemTitle = "{0}" -f (nullCoalesce $location.Name, "")
		$lineItemInfo = ((("<{0},{1}>" -f $xCoord, $yCoord) -join " ").Trim())
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen} {2, -$lineEntryRightSegmentLen} |" -f "$title", $lineItemTitle, $lineItemInfo
	}
}

function print-ListDetail()
{
	[CmdletBinding()]
	param(
		  $collection
		, $title
		, $count
		, $capacity
		, $includeZeroes
		, $infoEntryLeftSegmentLen  = 20
		, $lineEntryLeftSegmentLen  = 19
		, $lineEntryRightSegmentLen = 25
		, $lineEntryFullLen         = 45
	)
	
	write-debug "detailing $($collection.Count) list items..."
	
	if($collection.Count -gt 0 -or $includeZeroes)
	{
		$qtyHeader=""
		if($count -ne $null)
		{
			$qtyHeader = "($count"
			if($capacity -ne $null)
			{
				$qtyHeader += "/$capacity"
			}
			$qtyHeader += ")"
		}
		
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen}-{2, $lineEntryRightSegmentLen} |" -f "$title $qtyHeader", ("-"*$lineEntryLeftSegmentLen), ("-"*$lineEntryRightSegmentLen)
		foreach ($entry in $collection)
		{
			write-debug $entry
			if($entry.Value -eq 0 -and -not $includeZeroes)
			{
				write-debug "$($entry.Key) is zero, skipping)"
				continue
			}
			
			$lineItemTitle = ""
			$lineItemInfo  = ""
			
			if ($entry.GetType() -eq "string".GetType()) #simple string entry
			{
				$lineItemTitle = $entry
			}
			if ($entry.Name -ne $null) #Named-object reference entry
			{
				$lineItemTitle = "{0}" -f $entry.Name
				if($entry.Qty -ne $null -and $entry.Qty -gt 1)
				{
					$lineItemTitle = "{0}x {1}" -f $entry.Qty, $lineItemTitle
				}
				
				if($entry.Size -ne $null -or $entry.Qty -ne $null)
				{
					$lineItemInfo += "{0, $lineEntryRightSegmentLen}" -f ("("+((nullCoalesce $entry.Size, 1) * (nullCoalesce $entry.Qty, 1))+")")
				}
				else
				{
					$lineItemInfo += " {0, $lineEntryRightSegmentLen}" -f ""
				}
			}
			
			#last-ditch, probably won't be pretty
			if ($lineItemTitle -eq "")
			{
				$lineItemTitle="{0}" -f "", $entry
			}
			
			"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen} {2, $lineEntryRightSegmentLen} |" -f "", $lineItemTitle, $lineItemInfo
		}
	}
}

function get-ComponentValue()
{
	[cmdletBinding()]
	param(
		  $unit
		, $componentKey
	)

	$cEntry = $unit.Components | where-object {
		$_.Key -eq $componentKey
	}
	
	write-debug ("GET_ComponentValue: {0} for {1} is {2}" -f $componentKey, $unit.Name, $cEntry.Value)
	
	(nullCoalesce $cEntry.Value, 0)
}

function nullCoalesce()
{
	[cmdletBinding()]
	param(
		$items
	)
	
	($items -ne $null)[0]
}