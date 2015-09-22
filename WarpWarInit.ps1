#example invocation:
#     $cS=$null; cls; $cS = .\WarpWarInit.ps1 -Verbose; $cS.ComponentSpecs | format-table -property * -wrap -autosize


[cmdletBinding()]
param(

)

if($PSBoundParameters['Debug']) { $debugPreference = $onDebugAction }

#Game constants.
#"Hull_damage_value": 0 for "vanilla" rules; 1+ makes larger ships tougher than smaller ships with equal armor/shields/ecm.
#"TL_addTo_BPLimit" : 0 for "vanilla" rules; 1+ alters the BP-by-size calculation from the static max-size spec to (sqrt(MaxSize) * (sqrt(maxSize) + TL -1))"
#"TL_addTo_Damage"  : 1 for "vanilla" rules; 0 compensates for the increased damage capability that comes from having more BP for higher-TL ships."ration. PD gets all stats explicitly to help table-formatting.
$GameConfig_ReignOfStars=@"
{
	"Constants":{
	      "Combat_max_rounds":3	
		, "Hull_damage_value":1  
		, "TL_addTo_BPLimit" :1  
		, "TL_addTo_Damage"  :0  
	}
	, "ComponentSpecs": [
		  { "Name":"PD" , "BPCost": 1    , "Damage" : 0, "RoF":0, "Defense": 0, "ECM":0, "Hull":0, "MaxSize":  0, "PDPerMP":0, "Cargo": 0, "Power":1, "CompType":"Power"      , "Info" : { "LongName":"Power/Drive"                , "Description":"Total effective strength of a ship's engines."                                        } }
		, { "Name":"B"  , "BPCost": 1    , "Damage" : 1, "RoF":1                                                                                    , "CompType":"Weapon"     , "Info" : { "LongName":"Beams"                      , "Description":"Project a beam of destructive energy at a target."                                    } }
		, { "Name":"C"  , "BPCost": 1                  , "RoF":3                                                                                    , "CompType":"Weapon"     , "Info" : { "LongName":"Cannons"                    , "Description":"Launch Shells. Each Cannon may fire either 1, 2 or 3 Shells per combat round."        } }
		, { "Name":"T"  , "BPCost": 1                  , "RoF":1                                                                                    , "CompType":"Weapon"     , "Info" : { "LongName":"Tubes"                      , "Description":"Launch Missiles. Each Tube may launch one Missile per combat round."                  } }
		, { "Name":"SH" , "BPCost": 0.167, "Damage" : 1                                                                                             , "CompType":"Ammunition" , "Info" : { "LongName":"Shells"                     , "Description":"Fired by Cannons."                                                                    } }
		, { "Name":"M"  , "BPCost": 0.333, "Damage" : 2                                                                                             , "CompType":"Ammunition" , "Info" : { "LongName":"Missiles"                   , "Description":"Fired by Tubes."                                                                      } }
		, { "Name":"S"  , "BPCost": 1                           , "Defense": 1                                                                      , "CompType":"Defense"    , "Info" : { "LongName":"Screens"                    , "Description":"Ability of a ship to surround itself with a protective energy screen."                } }
		, { "Name":"A"  , "BPCost": 0.5                         , "Defense": 0                                                                      , "CompType":"Defense"    , "Info" : { "LongName":"Armor"                      , "Description":"Ablative hull reinforcement."                                                         } }
		, { "Name":"E"  , "BPCost": 1                           , "Defense": 0, "ECM":1                                                             , "CompType":"Defense"    , "Info" : { "LongName":"ECM"                        , "Description":"Electronic countermeasures. ECM points alter attacking Missiles' effective Drive."    } }
		, { "Name":"SR" , "BPCost": 1                                                                                                               , "CompType":"Carry"      , "Info" : { "LongName":"Systemship Rack"            , "Description":"Let a Warpship carry Systemships."                                                    } }
		, { "Name":"H"  , "BPCost": 1                                                                                        , "Cargo":10           , "CompType":"Carry"      , "Info" : { "LongName":"Hold"                       , "Description":"Contain cargo and/or BPs."                                                            } }
		, { "Name":"R"  , "BPCost": 5                                                                                                               , "CompType":"Utility"    , "Info" : { "LongName":"Repair"                     , "Description":"Use BPs in Hold or from Star to repair self or others during the build/repair event." } }
		, { "Name":"CP" , "BPCost":15                                                                                                               , "CompType":"Utility"    , "Info" : { "LongName":"Colony Pod"                 , "Description":"Establishes a new Colony when deployed."                                              } }
		, { "Name":"SSB", "BPCost": 7                                                  , "Hull": 8, "MaxSize": 64                                   , "CompType":"Hull"       , "Info" : { "LongName":"Small Starbase Hull"        , "Description":"For bases BP 64(H 8) or smaller. (Defsat)"                                            } }
		, { "Name":"MSB", "BPCost":13                                                  , "Hull":12, "MaxSize":144                                   , "CompType":"Hull"       , "Info" : { "LongName":"Medium Starbase Hull"       , "Description":"For bases BP144(H12) or smaller. (Station)"                                           } }
		, { "Name":"LSB", "BPCost":25                                                  , "Hull":20, "MaxSize":400                                   , "CompType":"Hull"       , "Info" : { "LongName":"Large Starbase Hull"        , "Description":"For bases BP400(H20) or smaller. (Fortress)"                                          } }
		, { "Name":"SWG", "BPCost": 3                                                  , "Hull": 3, "MaxSize":  9, "PDPerMP":1                      , "CompType":"Hull"       , "Info" : { "LongName":"Small Warp Generator Hull"  , "Description":"For ships BP  9(H 3) or smaller. (Escort)"                                            } }
		, { "Name":"MWG", "BPCost": 6                                                  , "Hull": 6, "MaxSize": 36, "PDPerMP":2                      , "CompType":"Hull"       , "Info" : { "LongName":"Medium Warp Generator Hull" , "Description":"For ships BP 36(H 6) or smaller. (Cruiser)"                                           } }
		, { "Name":"LWG", "BPCost": 9                                                  , "Hull": 8, "MaxSize": 64, "PDPerMP":3                      , "CompType":"Hull"       , "Info" : { "LongName":"Large Warp Generator Hull"  , "Description":"For ships BP 64(H 8) or smaller. (Capital)"                                           } }
		, { "Name":"GWG", "BPCost":12                                                  , "Hull":10, "MaxSize":100, "PDPerMP":3                      , "CompType":"Hull"       , "Info" : { "LongName":"Giant Warp Generator Hull"  , "Description":"For ships BP100(H10) or smaller. (Supercapital)"                                      } }
		, { "Name":"SSS", "BPCost": 0                                                  , "Hull": 3, "MaxSize":  9                                   , "CompType":"Hull"       , "Info" : { "LongName":"Small System Ship Hull"     , "Description":"For ships BP  9(H 3) or smaller. (Fighter/Escort)"                                    } }
		, { "Name":"MSS", "BPCost": 2                                                  , "Hull": 6, "MaxSize": 36                                   , "CompType":"Hull"       , "Info" : { "LongName":"Medium System Ship Hull"    , "Description":"For ships BP 36(H 6) or smaller. (Cruiser)"                                           } }
		, { "Name":"LSS", "BPCost": 4                                                  , "Hull": 8, "MaxSize": 64                                   , "CompType":"Hull"       , "Info" : { "LongName":"Large System Ship Hull"     , "Description":"For ships BP 64(H 8) or smaller. (Capital)"                                           } }
		, { "Name":"GSS", "BPCost": 6                                                  , "Hull":10, "MaxSize":100                                   , "CompType":"Hull"       , "Info" : { "LongName":"Giant System Ship Hull"     , "Description":"For ships BP100(H10) or smaller. (Supercapital)"                                      } }
	]
	, "ShipTemplate": {
		  "ID"                     : "TS1-01-001"
		, "Name"                   : "Template Ship"
		, "Owner"                  : "Template Owner"
		, "Location"               : {"ID":"-", "Name":"Origin", "X":0, "Y":0}
		, "TL"                     : 1
		, "BPCost"                 : 0
		, "BPMax"                  : 0
		, "Size"                   : 0
		, "PDPerMP"                : 0
		, "MP"                     : 0
		, "HUsed"                  : 0   
		, "HAvail"                 : 0
		, "SRUsed"                 : 0
		, "SRAvail"                : 0
		, "Components"             : {
			"PD":0, "B":0, "S":0, "T":0, "M":0, "SR":0, "C":0, "SH":0, "A":0, "E":0, "H":0, "R":0, "CP":0, "SWG":0, "MWG":0, "LWG":0, "GWG":0, "SSB":0, "MSB":0, "LSB":0, "SSS":0, "MSS":0, "LSS":0, "GSS":0
		}
		, "Universe"               : "Reign of Stars"
		, "Valid"                  : "???"
		, "Racks"                  : []
		, "Cargo"                  : []
		, "Damage"                 : {
			"PD":0, "B":0, "S":0, "T":0, "M":0, "SR":0, "C":0, "SH":0, "A":0, "E":0, "H":0, "R":0, "CP":0, "SWG":0, "MWG":0, "LWG":0, "GWG":0, "SSB":0, "MSB":0, "LSB":0, "SSS":0, "MSS":0, "LSS":0, "GSS":0
		}
		, "EffectiveAttrs"         : []
		, "ValidationResult"       : []
	}
	, "ShipSpecs": [
		{
		    "ID"        : "IWS-01-001"
		  , "Name"      : "Gladius-1"
		  , "Owner"     : "Empire"
		  , "Location"  : { "X":1, "Y":1 }
		  , "TL"        : 2
		  , "Components": { "SWG":1, "PD":4, "B":2, "S":1, "SR":2, "ZZZ":1, "LWG":0 }
		  , "Damage"    : { "ZZZ":1 }
		}
		, {
		    "ID"        : "IWS-01-002"
		  , "Name"      : "Gladius-2"
		  , "Owner"     : "Empire"
		  , "Components": { "SWG":1, "PD":4, "B":2, "S":1, "SR":2 }
		  , "Racks"     : ["ISS-0A-001", "BOGUS"]
		  , "Location"  : "SYS001"
		}
		, {
		    "ID"        : "ISS-0A-001"
		  , "Name"      : "Portero-1"
		  , "Owner"     : "Empire"
		  , "Components": { "SSS":1, "PD":4, "S":1, "H":2 }
		  , "Cargo"     : [{ "Name":"BP", "Size":1, "Qty":5 }, { "Name":"Fifth Space Marines", "Size":5, "Qty":1 }, "ISB-0A-00A"]
		  , "Location"  : "IWS-01-002"
		}
		, {
		    "ID"        : "ISB-0A-00A"
		  , "Name"      : "Orbituo-1"
		  , "Owner"     : "Empire"
		  , "Components": { "SSB":1, "PD":4, "S":2, "B":2 }
		  , "Location"  : "ISS-0A-001"
		  , "Damage"    : { "PD":2, "S":1, "B":2, "Core":1 }
		}
	]
	, "Systems": [
		{
			  "ID"      : "SYS001"
			, "Name"    : "Beta Hydri"
			, "X"       : "5"
			, "Y"       : "5"
		}
	]
}
"@

$Constants=@{}

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

	#Convert template's Components dictionary into a KeyValuePair array for consistency
	$shipT.Components = $shipT.Components.GetEnumerator() | ? { $_.Value -ne $null }


	
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
		write-verbose " - Filter out zero-value components"
		$ship.Components = $ship.Components.GetEnumerator() | ? { $_.Value -ne 0 }

		write-verbose " - Filter out irrelevant damage values"
		$ship.Damage     = remove-ExtraProperties   -parent $ship.Components -child $ship.Damage
		
		write-verbose "Replace reference IDs in e.g. 'Racks' and 'Cargo' arrays with references to Ships"
		$ship.Cargo      = replace-IDsWithReferences -collection $ship.Cargo -referenceCollection $shipSpecs
		$ship.Racks      = replace-IDsWithReferences -collection $ship.Racks -referenceCollection $shipSpecs

		write-verbose "Replace location IDs for $($ship.Name) in 'Location' property '$($ship.Location)' with references to Systems OR, failing that, Ships"
		$ship.Location   = (replace-IDsWithReferences -collection $ship.Location -referenceCollection @($systems + $shipSpecs))
		write-verbose "Location is now $($ship.Location)"
		
		write-verbose "Generate derived attributes from components, racks, cargo"
		generate-derivedAttrs -unit $ship -componentSpec $componentSpec

		write-verbose "Generate effective attribute values from components, damage"
		$ship.EffectiveAttrs   = (generate-effectiveAttrs -unit $ship)

		write-verbose "Generate validation errors from components, racks, cargo, damage"
		$ship.ValidationResult = (generate-validationResult -unit $ship)
			
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
	$unit.HAvail    = (get-ComponentValue -unit $unit -componentKey "H" ) * ($componentSpec | ? { $_.Name -eq "H" } ).Cargo
	$unit.SRUsed    = $unit.Racks.Count
	$unit.SRAvail   = (get-ComponentValue -unit $unit -componentKey "SR")
		
}

function generate-effectiveAttrs()
{
	[cmdletBinding()]
	param (
		$unit
	)
	$result = @{}
	
	#For each nonzero Component, subtract Damage value from Component value
	foreach ($c in $unit.Components.GetEnumerator())
	{
		$cKey           = $c.Key
		$specVal        = $c.Value
		$dmgVal         = ($unit.Damage.$cKey)+0
		$effectiveValue = ($specVal - $dmgVal)
		$result.$cKey   = $effectiveValue
		
		write-verbose ("{0} spec value is {1}, damage value is {2} -- effective value is {3}" -f $cKey, $specVal, $dmgVal, $effectiveValue )
	}

	$result
}

function generate-validationResult()
{
	[cmdletBinding()]
	param (
		$unit
	)
	
	$result = @()
	
	#SRAvail should be nonnegative
	#HAvail should be nonnegative
	#BPCost should be less than BPMax

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
		, [Decimal] $lineEntryRightSegmentLen =15
		, [Decimal] $lineEntryFullLen         =35
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
	$exclInfoFields = ("ID", "Name", "Cargo", "Components", "Damage", "DerivedAttrs", "EffectiveAttrs", "HAvail", "HUsed", "MP", "PDPerMP", "SRAvail", "SRUsed", "Location", "Racks", "Valid", "ValidationResult")
	#Ordered info fields
	$orderedInfoFields = ("Owner", "Universe", "TL", "BPCost", "BPMax", "Size",  "MP") 
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
		write-debug "Components"
		print-ListDetail -title "Components" -includeZeroes $includeZeroes -collection $s.Components -damageCollection $s.Damage #-count $s.Components.Count -capacity 99
		write-debug "Cargo"
		print-ListDetail -title "Cargo"      -includeZeroes $includeZeroes -collection $s.Cargo -count $s.HUsed  -capacity $s.HAvail
		write-debug "Racks"		
		print-ListDetail -title "Racks"      -includeZeroes $includeZeroes -collection $s.Racks -count $s.SRUsed -capacity $s.SRAvail
		write-debug "Location"
		print-ListDetail -title "Location"   -includeZeroes $includeZeroes -collection $s.Location
		write-debug "EffectiveAttrs (incl damage annotations)"
		write-debug "ValidationResult (incl 'Valid' ruling)"
		
	#Footer
	"|-{0,-$infoEntryLeftSegmentLen}--{1, -$lineEntryFullLen}-|" -f (("-"*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))
}

function print-listDetail()
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
		, $lineEntryRightSegmentLen = 15
		, $lineEntryFullLen         = 35
		, $damageCollection         = $null
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
		
		"| {0,-$infoEntryLeftSegmentLen}| {1} |" -f "$title $qtyHeader", ("-"*$lineEntryFullLen)
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
				$eKey    = $entry.Key
				$eValTxt = $entry.Value
				
				
				if($damageCollection -ne $null -and $damageCollection.$eKey -ne $null -and $damageCollection.$eKey -gt 0)
				{
					$eValTxt = "$eValTxt {0,8}" -f "(HIT:$($damageCollection.$eKey))"
				}
				else
				{
					$eValTxt = "$eValTxt {0,8}" -f ""
				}
				"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen}:{2, $lineEntryRightSegmentLen} |" -f "", $entry.Key, $eValTxt
			}
			else
			{
				write-debug "$entry is not a key-value pair"
				
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
				if ($title -eq "Location" )
				{
					#Valid Possibilities: a) unit has a bare X,Y coordinate or System as its Location
					#                     b) unit is in Racks or Cargo - its parent is of type (a)
					#                     c) unit is in Cargo - its parent is in Racks, and ITS parent is of Type (a)
					#                     d) ???
					$xCoord = (nullCoalesce($entry.X, $entry.Location.X, $entry.Location.Location.X, "?"))
					$yCoord = (nullCoalesce($entry.Y, $entry.Location.Y, $entry.Location.Location.Y, "?"))
					$lineItemInfo = ((("<{0},{1}>" -f $xCoord, $yCoord) -join " ").Trim())
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

$GameData = init -cfg $GameConfig_ReignOfStars
write-verbose "COMPONENTS"
write-verbose (summarize-ComponentData -compData $GameData.ComponentSpecs | format-list | out-string )
write-verbose "TEMPLATE"
write-verbose ("`n"+"`n"+ (printShipInfo -s $GameData.ShipTemplate -includeZeroes | out-string) )
write-verbose "SHIPS"
write-verbose ("`n"+( $GameData.ShipSpecs    | % { "`n"; printShipInfo -s $_ } | out-string))
$GameData