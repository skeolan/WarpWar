#example invocation:
#     $cS=$null; cls; $cS = .\WarpWarInit.ps1 -Verbose; $cS.ComponentSpecs | format-table -property * -wrap -autosize


[cmdletBinding()]
param(
	$gameData = "$PSScriptRoot\GameConfig-ReignOfStars.json"
)

if($PSBoundParameters['Debug']) { $debugPreference = $onDebugAction }


$GameState  = $null
$GameEngine = import-module $PSScriptRoot\WarpWarGameEngine.psm1 -Force
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
		write-verbose ("Executing turn {0} orders for {1}" -f $turn, $ship.Name )
		$attacker = $ship
		#$defender = @($GameState.ShipSpecs | ? { $_.ID -eq  $attacker.TurnOrders[$tI].Target})[0]
		$result = execute-TurnOrder $attacker $turn $GameState -verbose
		if($result) { write-verbose "Turn executed successfully"         }
		else        { write-verbose "Turn did not execute successfully?" }
		write-verbose "Turn completed, proceeding..."
	} 
}

write-verbose "Combat completed!"

$GameState