#example invocation:
#     cls; $gs = .\WarpWarInit.ps1 -Verbose; $gs


[cmdletBinding()]
param(
	#$gameData = "$PSScriptRoot\GameConfig-ReignOfStars.json"
	$gameData = "$PSScriptRoot\GameConfig-VanillaWW.json"
)

if($PSBoundParameters['Debug']) { $debugPreference = $onDebugAction }


$GameState     = $null
$GameEngine    = import-module $PSScriptRoot\WarpWarGameEngine.psm1 -Force
$DisplayEngine = import-module $PSScriptRoot\WarpWarDisplayEngine.psm1 -Force
$GameState     = init -cfg (get-content $gameData)
$constants     = $GameState.Constants 

write-verbose "CONSTANTS"
write-verbose ($constants | % { $_ } | out-string)
write-verbose "COMPONENTS"
write-verbose (summarize-ComponentData -compData $GameState.ComponentSpecs | format-list | out-string )
write-verbose "TEMPLATE"
write-verbose ("`n"+"`n"+ (printShipInfo -s $GameState.ShipTemplate -includeZeroes | out-string) )
write-verbose "SHIPS"
write-verbose ("`n"+( $GameState.ShipSpecs    | % { "`n"; printShipInfo -s $_ } | out-string))
write-verbose "SYSTEMS"
#write-verbose ("`n"+( $GameState.Systems    | % { "`n"; printSystemInfo -s $_ } | out-string))

$numTurns     = 2
$combatShips  = $GameState.ShipSpecs | ? { $_.TurnOrders -ne $null }
$combatResult = Resolve-CombatTurns  $numTurns $combatShips $GameState

write-verbose "Combat completed!"
write-verbose "Combat results:"
write-verbose ""
write-verbose ("`n" + (Summarize-CombatResult $combatResult | out-string))

@{GameState = $GameState; CombatResults=$combatResult}