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

$numTurns     = 2
$combatShips  = $GameState.ShipSpecs | ? { $_.TurnOrders -ne $null }
$combatResult = @{}

foreach($turn in (1..$numTurns) ) 
	{ 
	$resultSet = @()
	foreach ($ship in $combatShips) 
	{ 
		write-verbose ("Executing turn {0} orders for {1}" -f $turn, $ship.Name )
		$attacker      = $ship
		$attackResults     = execute-TurnOrder $attacker $turn $GameState -verbose
		if($attackResults) 
					{ 
						write-verbose "Turn $turn for $($attacker.Name) executed successfully"
						write-verbose "$($resultSet.Count) attack results"
						$resultSet += $attackResults
					}
		else           { write-verbose "Turn did not execute successfully?" }
		write-verbose "Turn completed, proceeding..."
	} 
	#Apply $resultSet to gamestate
	#Remove any escaped or destroyed ships from $combatShips
	$combatResult."Turn$turn" = ($resultSet) #Commit set of attack results to the combatResult array
}

write-verbose "Combat completed!"
write-verbose "Combat results:"
foreach($key in ($CombatResult.Keys | sort)) 
{ 
	write-verbose $key
	write-verbose "$($CombatResult[$key].Count) attack(s)" 
	foreach($atk in $CombatResult[$key]) 
	{ 
		write-verbose ("{0,-10} {4,-7} {1,-10} with {6, 3}/{7, -3} for {2,4} ( {3}, {4}, {5} )" `
		-f $atk.attacker, $atk.target, $atk.damage, $atk.attackType, $atk.crtResult, $atk.turnResult, $atk.weapon, $atk.ammo); 
	} 
}

@{GameState = $GameState; CombatResults=$combatResult}