#example invocation:
#     cls; $cS = .\WarpWarInit.ps1 -Verbose; $cS.ComponentSpecs | format-table -property * -wrap -autosize


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
		  { "Name":"PD" , "BPCost": 1    , "Damage" : 0, "RoF":0, "Defense": 0, "ECM":0, "Hull":0, "maxSize":  0, "PDPerMP":0, "Power":1, "CompType":"Power"      , "Info" : { "LongName":"Power/Drive"                , "Description":"Total effective strength of a ship's engines."                                        } }
		, { "Name":"B"  , "BPCost": 1    , "Damage" : 1, "RoF":1                                                                        , "CompType":"Weapon"     , "Info" : { "LongName":"Beams"                      , "Description":"Project a beam of destructive energy at a target."                                    } }
		, { "Name":"C"  , "BPCost": 1                  , "RoF":3                                                                        , "CompType":"Weapon"     , "Info" : { "LongName":"Cannons"                    , "Description":"Launch Shells. Each Cannon may fire either 1, 2 or 3 Shells per combat round."        } }
		, { "Name":"T"  , "BPCost": 1                  , "RoF":1                                                                        , "CompType":"Weapon"     , "Info" : { "LongName":"Tubes"                      , "Description":"Launch Missiles. Each Tube may launch one Missile per combat round."                  } }
		, { "Name":"SH" , "BPCost": 0.167, "Damage" : 1                                                                                 , "CompType":"Ammunition" , "Info" : { "LongName":"Shells"                     , "Description":"Fired by Cannons."                                                                    } }
		, { "Name":"M"  , "BPCost": 0.333, "Damage" : 2                                                                                 , "CompType":"Ammunition" , "Info" : { "LongName":"Missiles"                   , "Description":"Fired by Tubes."                                                                      } }
		, { "Name":"S"  , "BPCost": 1                           , "Defense": 1                                                          , "CompType":"Defense"    , "Info" : { "LongName":"Screens"                    , "Description":"Ability of a ship to surround itself with a protective energy screen."                } }
		, { "Name":"A"  , "BPCost": 0.5                         , "Defense": 0                                                          , "CompType":"Defense"    , "Info" : { "LongName":"Armor"                      , "Description":"Ablative hull reinforcement."                                                         } }
		, { "Name":"E"  , "BPCost": 1                           , "Defense": 0, "ECM":1                                                 , "CompType":"Defense"    , "Info" : { "LongName":"ECM"                        , "Description":"Electronic countermeasures. ECM points alter attacking Missiles' effective Drive."    } }
		, { "Name":"SR" , "BPCost": 1                                                                                                   , "CompType":"Carry"      , "Info" : { "LongName":"Systemship Rack"            , "Description":"Let a Warpship carry Systemships."                                                    } }
		, { "Name":"H"  , "BPCost": 0.1                                                                                                 , "CompType":"Carry"      , "Info" : { "LongName":"Hold"                       , "Description":"Contain cargo and/or BPs."                                                            } }
		, { "Name":"R"  , "BPCost": 5                                                                                                   , "CompType":"Utility"    , "Info" : { "LongName":"Repair"                     , "Description":"Use BPs in Hold or from Star to repair self or others during the build/repair event." } }
		, { "Name":"CP" , "BPCost":15                                                                                                   , "CompType":"Utility"    , "Info" : { "LongName":"Colony Pod"                 , "Description":"Establishes a new Colony when deployed."                                              } }
		, { "Name":"SSB", "BPCost": 7                                                  , "Hull": 8, "maxSize": 64                       , "CompType":"Hull"       , "Info" : { "LongName":"Small Starbase Hull"        , "Description":"For bases BP 64(H 8) or smaller. (Defsat)"                                            } }
		, { "Name":"MSB", "BPCost":13                                                  , "Hull":12, "maxSize":144                       , "CompType":"Hull"       , "Info" : { "LongName":"Medium Starbase Hull"       , "Description":"For bases BP144(H12) or smaller. (Station)"                                           } }
		, { "Name":"LSB", "BPCost":25                                                  , "Hull":20, "maxSize":400                       , "CompType":"Hull"       , "Info" : { "LongName":"Large Starbase Hull"        , "Description":"For bases BP400(H20) or smaller. (Fortress)"                                          } }
		, { "Name":"SWG", "BPCost": 3                                                  , "Hull": 3, "maxSize":  9, "PDPerMP":1          , "CompType":"Hull"       , "Info" : { "LongName":"Small Warp Generator Hull"  , "Description":"For ships BP  9(H 3) or smaller. (Escort)"                                            } }
		, { "Name":"MWG", "BPCost": 6                                                  , "Hull": 6, "maxSize": 36, "PDPerMP":2          , "CompType":"Hull"       , "Info" : { "LongName":"Medium Warp Generator Hull" , "Description":"For ships BP 36(H 6) or smaller. (Cruiser)"                                           } }
		, { "Name":"LWG", "BPCost": 9                                                  , "Hull": 8, "maxSize": 64, "PDPerMP":3          , "CompType":"Hull"       , "Info" : { "LongName":"Large Warp Generator Hull"  , "Description":"For ships BP 64(H 8) or smaller. (Capital)"                                           } }
		, { "Name":"GWG", "BPCost":12                                                  , "Hull":10, "maxSize":100, "PDPerMP":3          , "CompType":"Hull"       , "Info" : { "LongName":"Giant Warp Generator Hull"  , "Description":"For ships BP100(H10) or smaller. (Supercapital)"                                      } }
		, { "Name":"SSS", "BPCost": 0                                                  , "Hull": 3, "maxSize":  9                       , "CompType":"Hull"       , "Info" : { "LongName":"Small System Ship Hull"     , "Description":"For ships BP  9(H 3) or smaller. (Fighter/Escort)"                                    } }
		, { "Name":"MSS", "BPCost": 2                                                  , "Hull": 6, "maxSize": 36                       , "CompType":"Hull"       , "Info" : { "LongName":"Medium System Ship Hull"    , "Description":"For ships BP 36(H 6) or smaller. (Cruiser)"                                           } }
		, { "Name":"LSS", "BPCost": 4                                                  , "Hull": 8, "maxSize": 64                       , "CompType":"Hull"       , "Info" : { "LongName":"Large System Ship Hull"     , "Description":"For ships BP 64(H 8) or smaller. (Capital)"                                           } }
		, { "Name":"GSS", "BPCost": 6                                                  , "Hull":10, "maxSize":100                       , "CompType":"Hull"       , "Info" : { "LongName":"Giant System Ship Hull"     , "Description":"For ships BP100(H10) or smaller. (Supercapital)"                                      } }
	]
	, "ShipTemplate": {
		  "ID"                     : "TS1-01-001"
		, "Name"                   : "Template Ship"
		, "Owner"                  : "Template Owner"
		, "Location"               : {"ID":"-", "Name":"-", "X":0, "Y":0}
		, "TL"                     : 1
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
		}
		, {
		    "ID"        : "ISS-0A-001"
		  , "Name"      : "Portero-1"
		  , "Owner"     : "Empire"
		  , "Components": { "SSS":1, "PD":4, "S":1, "C":20 }
		  , "Cargo"     : [{ "Name":"BP", "Size":1, "Qty":5 }, { "Name":"Fifth Space Marines", "Size":5, "Qty":1 }, "ISB-0A-00A"]
		}
		, {
		    "ID"        : "ISB-0A-00A"
		  , "Name"      : "Orbituo-1"
		  , "Owner"     : "Empire"
		  , "Components": { "SSB":1, "PD":4, "S":2, "B":2 }
		}
	]
}
"@

function init()
{						
	[cmdletBinding()]
	param(
		$cfg
	)
	$GameData = $cfg | ConvertFrom-Json
	$GameData
	
	$summary = summarize-ComponentData -compData $GameData.ComponentSpecs | out-string
	write-verbose $summary
	
	Init-ShipsFromTemplate -template $GameData.ShipTemplate -componentSpec $GameData.ComponentSpecs -shipSpec $GameData.ShipSpecs
	Init-ShipCollections   -template $GameData.ShipTemplate -componentSpec $GameData.ComponentSpecs -shipSpec $GameData.ShipSpecs
}

function print-ComponentInfo()
{
	[cmdletBinding()]
	param(
		$comp
	)
	"  {0,-26} {1}" -f  $comp.Info.LongName, $comp.Info.Description
	"  {0,-26} {1}"   -f " ", ( $comp  )
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

	@($util, $weps, $ammo, $defs, $hull, $bays) | format-table -autosize -wrap -property *
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
		foreach ($tProperty in $shipT | Get-Member -type NoteProperty)
		{ 
			$propName = $tProperty.Name
			$propVal  = $shipT.$propName
			
			if($ship.$($tProperty.Name) -eq $null) 
			{
				$ship | add-member -type NoteProperty -Name $propName -Value $propVal
			} 
		}
	}
		
	$cS.ShipSpecs[0] | format-table | out-string | write-verbose	
}

function init-ShipCollections
{
	[cmdletBinding()]
	param ( 
		  $template
		, $componentSpec
		, $shipSpecs
	)
	
	foreach ($ship in $shipSpecs)
	{
		#Remove items from "Components" array for which value is zero
		write-verbose " - Filter out zero-value components"
		$ship.Components = get-NonzeroProperties -collection $ship.Components

		#Remove items from "Damage" array if ship lacks that component
		write-verbose " - Filter out irrelevant damage values"
		$ship.Damage     = remove-ExtraProperties   -parent $ship.Components -child $ship.Damage
		
		#Replace reference IDs in e.g. "Racks" and "Cargo" arrays with reference to objects
		#WORKS: $cS.ShipSpecs | ? {$_.ID -eq "ISS-0A-001"} | % { $_.Cargo } | % { if ($_.getType().Name -ne "String") { $_ } else { $id=$_; $cS.ShipSpecs | ? {$_.ID -eq $id }  } } | format-list

		#??? Replace location IDs in "Location" property with reference to System
		
	}

}

function get-NonzeroProperties()
{
	[cmdletBinding()]
	param (
		$collection
	)
	
		$collectionKeys  = get-member -type NoteProperty -inputObject $collection
		write-verbose "   Collection will be trimmed of zero-value entries:"
		write-verbose $($collectionKeys | out-string)
		$nonzeroVals = new-Object PSCustomObject
		foreach ($cItem in $collectionKeys)
		{
			$cKey    = $cItem.Name
			$cVal    = $collection.$cKey
			$logText = "     {0,-10}" -f "$cKey : $cVal"
			if ($cVal -ne 0)
			{
				$logText += ""
				$nonzeroVals | add-member -type NoteProperty -Name $cKey -Value $cVal
			}
			else
			{
				$logText += " is zero, excising"
			}
			write-verbose $logText
		}
		write-verbose "   Values kept:"
		write-verbose ($nonzeroVals | format-list | out-string)
		
		$nonzeroVals
}

function remove-ExtraProperties()
{
	[cmdletBinding()]
	param (
		  $parent #Collection whose list of properties is "canonical"
		, $child  #Collection should not contain any properties absent from parent
	)
	
		$collectionKeys  = get-member -type NoteProperty -inputObject $parent
		$childVals = new-Object -type PSCustomObject
		foreach ($cItem in $collectionKeys)
		{
			$cKey = $cItem.Name
			$cVal = (nullCoalesce $child.$cKey, 0)
			$childVals | add-member -type NoteProperty -Name  $cKey -Value $cVal
			$logText = "     {0,-10}" -f "$cKey : $cVal added to child collection"
			write-verbose $logText
		}
		$childVals
}

function nullCoalesce()
{
	[cmdletBinding()]
	param(
		$items
	)
	
	($items -ne $null)[0]
}

init -cfg $GameConfig_ReignOfStars