function init()
{						
	[cmdletBinding()]
	param(
		$cfg
	)
	Add-Type -AssemblyName System.Web.Extensions
	$GameData  = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Deserialize($cfg, [System.Collections.Hashtable])
	$Constants = $GameData.Constants
	
	$CombatEngine     = import-module $PSScriptRoot\WarpWarCombatEngine.psm1      -Force
	$ValidationEngine = import-module $PSScriptRoot\WarpWarValidationEngine.psm1  -Force
	
	Init-ShipsFromTemplate -template $GameData.ShipTemplate -componentSpec $GameData.ComponentSpecs -shipSpec $GameData.ShipSpecs
	Init-ShipCollections   -template $GameData.ShipTemplate -componentSpec $GameData.ComponentSpecs -shipSpec $GameData.ShipSpecs -systems $GameData.Systems
	Init-UnitMethods       -units    $GameData.ShipSpecs
	
	$GameData	
}

function Resolve-CombatTurns ()
{
	[CmdletBinding()]
	param(
		  $numTurns
		, $combatShips
		, $GameState
	)

	$combatResult = @{}

	foreach($turn in (1..$numTurns) ) 
		{ 
		$resultSet = @()
		foreach ($ship in $combatShips) 
		{ 
			write-verbose ("Executing turn {0} orders for {1}" -f $turn, $ship.Name )
			$attacker      = $ship
			$attackResults = execute-TurnOrder $attacker $turn $GameState -verbose
			if($attackResults) 
						{ 
							write-verbose "Turn $turn for $($attacker.Name) executed successfully"
							write-verbose "$($resultSet.Count) attack results"
							$resultSet += $attackResults
						}
			else           { write-verbose "Turn did not execute successfully?" }
		} 
		#TODO: Apply $resultSet to gamestate
		#TODO: Remove any escaped or destroyed ships from $combatShips
		$combatResult."Turn $turn" = ($resultSet) #Commit set of attack results to the combatResult array
	}
	
	$combatResult
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
		#$ship.Components      = $ship.Components.GetEnumerator()      | ? { $_.Value -ne 0 }
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
	$unit.MP       = calculate-MovementPoints -drive $unit.Components.PD -efficiency $unit.PDPerMP

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

	foreach ($item in $attrSet.GetEnumerator())
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

function nullCoalesce()
{
	[cmdletBinding()]
	param(
		$items
	)
	
	($items -ne $null)[0]
}