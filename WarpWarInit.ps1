#example invocation:
#     $cS=$null; cls; $cS = .\WarpWarInit.ps1 -Verbose; $cS.ComponentSpecs | format-table -property * -wrap -autosize


[cmdletBinding()]
param(
	$gameData = "$PSScriptRoot\GameConfig-ReignOfStars.json"
)

if($PSBoundParameters['Debug']) { $debugPreference = $onDebugAction }

#Game constants.
#"Hull_damage_value": 0 for "vanilla" rules; 1+ makes larger ships tougher than smaller ships with equal armor/shields/ecm.
#"TL_addTo_BPLimit" : 0 for "vanilla" rules; 1+ alters the BP-by-size calculation from the static max-size spec to (sqrt(MaxSize) * (sqrt(maxSize) + TL -1))"
#"TL_addTo_Damage"  : 1 for "vanilla" rules; 0 compensates for the increased damage capability that comes from having more BP for higher-TL ships."ration. PD gets all stats explicitly to help table-formatting.

$GameState  = $null
$GameEngine = import-module $PSScriptRoot\WarpWarGameEngine.psm1
$GameState  = init -cfg (get-content $gameData)
$constants  = $GameState.Constants 

write-verbose "CONSTANTS"
write-verbose ($constants | % { $_ } | out-string)
write-verbose "COMPONENTS"
write-verbose (summarize-ComponentData -compData $GameState.ComponentSpecs | format-list | out-string )
write-verbose "TEMPLATE"
write-verbose ("`n"+"`n"+ (printShipInfo -s $GameState.ShipTemplate -includeZeroes | out-string) )
write-verbose "SHIPS"
write-verbose ("`n"+( $GameState.ShipSpecs    | % { "`n"; printShipInfo -s $_ } | out-string))

$combatShips = $GameState.ShipSpecs | ? { $_.TurnOrders -ne $null }
foreach($turn in (1,2) ) 
	{ 
	foreach ($ship in $combatShips) 
	{ 
		write-host ("Executing turn {0} orders for {1}" -f $turn, $ship.Name )
	} 
}

write-verbose @"
See the '`$GameState' object for more info.
"@