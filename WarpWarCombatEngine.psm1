#WarpWarCombatEngine

function execute-TurnOrder()
{
	[cmdletBinding()]
	param (
		  $attacker
		  , $turn
		  , $gameConfig
	)
	
	$gameConstants = $gameConfig.Constants
	
	#component data structures useful for adjudicating results
	$cs   = $gameConfig.ComponentSpecs
	$weps = $cs | ? { $_.CompType -eq "Weapon"     } # or $_.RoF -ne $null if you want to be fancy
	$ammo = $cs | ? { $_.CompType -eq "Ammunition" }
	$defs = $cs | ? { $_.CompType -eq "Defense"    }
	$hull = $cs | ? { $_.CompType -eq "Hull"       }
	$bays = $cs | ? { $_.CompType -eq "Carry"      }
	$util = $cs | ? { $_.CompType -eq "Utility" -or $_.CompType -eq  "Power" }
	
	$attackResults = @()
	
	$ao       = $attacker.TurnOrders[$turn-1]
	#if((Validate-Orders($a $ao)) -eq $false) { return $false }
	
	foreach ($attack in $ao.Attacks)
	{
		$defender       = $gameConfig.ShipSpecs | where {$_.ID -eq $attack.Target}
		$do             = $defender.TurnOrders[$turn-1]
		$attackResult   = resolve-Attack $gameConfig $attacker $ao $attack $defender $do

		#ugh, side effects
		$do.EcmUsed    += $attackResult.ecmUsed

		$attackResults += $attackResult
	}
	
	#Attacks take effect simultaneously, so apply damage or otherwise change state only after resolving all attacks.
	foreach ($r in $attackResults)
	{
		$target = ($gameConfig.ShipSpecs | where { $_.ID -eq $r.Target})
		Apply-AttackResultToTarget $r $target $gameConstants.TL_addTo_Screens
	}
	
	write-verbose ( "[ENGINE:Execute-TurnOrder] Result: {0} attacks resolved" -f $attackResults.Count )
	$attackResults
}


function Resolve-Attack()
{
	[cmdletBinding()]
	param (
		$gameConfig
		, $attacker
		, $attackerOrders
		, $attack
		, $defender
		, $defenderOrders
	)
	
	
	write-verbose ( "[ENGINE:Resolve-Attack]     Orders: {0} : {1} at Drive {2}" -f $attacker.Name, $attackerOrders.Tactic, $attackerOrders.PowerAllocation.PD)
	$crt      = $gameConfig.CombatResults
	$maxDelta = NullCoalesce($gameConfig.Constants.Combat_max_DriveDiff, 5)

	#Attack Result object
	$ar = @{
		"damage"        = 0;
		"crtResult"     = "";
		"turnResult"    = "Continue";
		"attackType"    = $( If( (NullCoalesce($attack.WeaponDrive, -1)) -eq -1) {"direct"} Else {"indirect"} );
		"driveDiff"     = $( (NullCoalesce($attack.WeaponDrive, $attackerOrders.PowerAllocation.PD, 0)) - (NullCoalesce($defenderOrders.PowerAllocation.PD, $defender.PowerAllocation.PD, 0)) );

		"attacker"      = $attacker.ID;
		"attackerName"  = $attacker.Name;
		"attackerOrders"= $attackerOrders;
		"attackerPower" = NullCoalesce($attackerOrders.PowerAllocation, $attacker.PowerAllocation)
		"tactic"        = NullCoalesce($attackerOrders.Tactic, "??");
		"drive"         = NullCoalesce($attack.WeaponDrive, $attackerOrders.PowerAllocation.PD, 0);
		"weapon"        = NullCoalesce ($attack.Weapon, "??");
		"ammo"          = NullCoalesce ($attack.WeaponAmmo, $attack.Weapon);
		"power"         = NullCoalesce ($attack.Power, $attackerOrders.PowerAllocation.$($attack.Weapon), 0);
		"shots"         = NullCoalesce ($attack.RoF, 1);
		"TL"            = [Math]::Max((NullCoalesce($attack.TL, $attackerOrders.TL, $attacker.TL, 1)), 1);

		"target"        = $defender.ID;
		"targetName"    = $defender.Name;
		"targetOrders"  = $defenderOrders;
		"targetPower"   = NullCoalesce($defenderOrders.PowerAllocation, $defender.PowerAllocation);
		"targetTactic"  = NullCoalesce($defenderOrders.Tactic, "??");
		"targetDrive"   = NullCoalesce($defenderOrders.PowerAllocation.PD, $defender.PowerAllocation.PD, 0);
		"targetTL"      = [Math]::Max((NullCoalesce($do.TL, $d.TL, 1)), 1);
		"ecmUsed"       = NullCoalesce ($defenderOrders.EcmUsed, 0);
		"ecmRemaining"  = [MATH]::MAX( (($defenderOrders.PowerAllocation.E) - (NullCoalesce($defenderOrders.EcmUsed, 0))), 0);
	}
		
	write-verbose ("[ENGINE:Resolve-Attack]     - [{0}]({1}) with {2} shot(s) and power [$($ar.power)] from {3} - {4} at speed {5} vs [{6}]({7}) {8} at speed {9} and ECM {10}/{11} -- TL {12} vs {13}" `
	               -f $ar.attackerName, $ar.attacker, $ar.shots, $ar.Weapon, $ar.tactic, $ar.drive, $ar.targetName, $ar.target, $ar.targetTactic, $ar.targetDrive, $ar.ecmUsed, $ar.ecmRemaining, $ar.TL, $ar.targetTL)
	
	$ar.crtResult = Calculate-AttackResult $ar.tactic $ar.targetTactic $ar.driveDiff $crt $maxdelta
	if($ar.ecmRemaining -gt 0 -and $ar.crtResult -like "Hit*" -and $ar.attackType -eq "indirect")
	{
		$ar = Calculate-ECMResult $crt $ar $maxDelta
	}

	if($ar.crtResult -ne "Miss" -and $ar.crtResult -ne "Escapes")
	{
		$ar.Damage = Calculate-WeaponDamage $ar.weapon $ar.power $ar.shots $gameConfig.ComponentSpecs $ar.crtResult $ar.Ammo $ar.TL ($gameConfig.Constants.TL_addTo_Damage -gt 0)
	}		

	if($ar.Damage -ne 0)
	{
		write-verbose ( "{0}Target hit for {1} damage!" -f "[ENGINE:Resolve-Attack]     ", $ar.Damage)
	}
	if($ar.crtResult -eq "Miss")
	{
		write-verbose ("{0} {1} attack with {2} missed {3} !" -f "[ENGINE:Resolve-Attack]     ", $ar.attackerName, $ar.weapon, $ar.targetName)
	}
	if($ar.crtResult -eq "Escapes")
	{
		write-verbose ("{0} {1} attack with {2} missed and permitted {3} to escape!" -f "[ENGINE:Resolve-Attack]     ", $ar.attackerName, $ar.weapon, $ar.targetName)
		$ar.turnResult="Escapes"
	}
	
	#Return
	$ar
}

function Apply-AttackResultToTarget()
{
  [CmdletBinding()]
  param(
	$attackResult
	, $target
	, $TL_addTo_Screens=$true
	) 

	$damageToAllocate = $attackResult.Damage
	
	write-verbose ("[{0, -30}]: {1,3} damage to [{2}] -- S[{3}], A[{4}] - TL affects Screens is {4}" -f $MyInvocation.MyCommand, $attackResult.damage, $target.Name, $target.ScreensRemaining, $target.ArmorRemaining, $TL_addTo_Screens )
	
	#Utilize the unit's specified Damage Vector if present, else just apply damage in order of listed Components
	$damageVector            = NullCoalesce($target.DamageVector, $target.Components)
	$target.ScreensRemaining = NullCoalesce($target.ScreensRemaining, (Calculate-ScreenRating $target $attackResult.TargetOrders $TL_addTo_Screens))
	$target.ArmorRemaining   = NullCoalesce($target.ArmorRemaining, $target.Components.A, 0)
	write-verbose ( "Target is [{0}] with Screens [{1}] (currently [{2}]) and armor [{3}]" -f $target.Name, $target.Components.S, $target.ScreensRemaining, $target.ArmorRemaining)

	$d=0
	while($d -lt $damageToAllocate)
	{
		#First, buy down damage with Screens
		if      ($target.ScreensRemaining -gt 0) 
		{ 
			$damageDescriptor = "SCREENS"
			$target.ScreensRemaining--
			$d++
		}
		#Next, apply damage to Armor
		elseIf ($target.ArmorRemaining   -gt 0) 
		{ 
			$damageDescriptor = "ARMOR"
			$target.ArmorRemaining-- 
			$d++
		}
		#Next, start burning through components in the order listed in the Unit's Damage Vector
		else 
		{ 
			$damageDescriptor = "INTERNALS"
			$d += (Apply-DamageToUnitComponents $target $damageVector)
		}
		
		write-verbose ("   [  {0}]: $d/$damageToAllocate to $($target.Name) $damageDescriptor" -f $MyInvocation.MyCommand)
	}
}

function Apply-DamageToUnitComponents()
{
	[CmdletBinding()]
	param(
		$unit
		, $damageVector	
		, $damageAmount=1
	)
	
	$vectorSummary = ""
	
	foreach($kvp in $damageVector.GetEnumerator())
	{
		$vectorSummary += ("{0}:{1} " -f $kvp.Key, $kvp.Value)
	}
	
	$vectorSummary += ""
	
	write-verbose ( "   [{0}]: {1} damage to {2} onto vector [{3}]" -f $MyInvocation.MyCommand, $damageAmount, $unit.Name, $vectorSummary )
	$damageApplied = 1
	
	#return
	$damageApplied
}

function Calculate-AttackResult()
{
 [CmdletBinding()]
 param(
	  $aTac
	, $dTac
	, $driveDiff
	, $CRT                  #Combat Results Table lookup object, structured for lookups like AttackerTactic.DefenderTactic[DriveDiff]
	, $maxDelta=5           #Maximum absolute value of drive difference - all out-of-bounds results are Miss or Escapes
	, $attackType="direct"  #Potentially used in future for more advanced CRT rules (i.e. different CRT arrays for different weapon types)
	)
	
	#return
	$CRT.$aTac.$dTac[(Get-DriveDiffIndex $driveDiff $maxDelta)]
}

function Calculate-ECMResult()
{
 [CmdletBinding()]
 param(
	  $crt
	, $resultObject 
	, $maxDelta 
	, $TL_addTo_ECM=$true
 )
	
	$aTac         = $resultObject.tactic
	$dTac         = $resultObject.targetTactic
	$aTL          = $resultObject.TL
	$dTL          = $resultObject.targetTL
	$driveDiff    = $resultObject.drive - $resultObject.targetDrive
	$ecmAvailable = $resultObject.ecmRemaining
	$ecmRemaining = $resultObject.ecmRemaining
	$ecmToUse     = 0
	
	#No reason to burn ECM to turn a "Miss" into an "Escapes" since only direct-fire attacks are evaluated in retreat resolution.
	while($resultObject.crtResult -like "Hit*" -and ++$ecmToUse -le $ecmAvailable)
	{
		write-verbose ("  [{0,-20}] : evaluate using ECM {1} / {2}" -f $MyInvocation.MyCommand, $ecmToUse, $ecmAvailable)
		$driveDiffAdj = [Math]::Max(0, ($dTL - $aTL + $ecmToUse))
		if($driveDiffAdj -gt 0) 
		{
			$lowResult        = Calculate-AttackResult $aTac $dTac ($driveDiff - $driveDiffAdj) $CRT $maxDelta
			$midResult        = $resultObject.crtResult
			$highResult       = Calculate-AttackResult $aTac $dTac ($driveDiff + $driveDiffAdj) $CRT $maxDelta
			
			$lowDamageBonus  = Get-HitDamageBonus $lowResult 
			$midDamageBonus  = Get-HitDamageBonus $midResult 
			$highDamageBonus = Get-HitDamageBonus $highResult

			write-verbose ("  [{0,-20}] : using ECM {1} changes result [$driveDiff] '$midResult' ($midDamageBonus) to [$($driveDiff-$driveDiffAdj)] '{2}' ($lowDamageBonus) or [$($driveDiff+$driveDiffAdj)] '{3}' ($highDamageBonus)" -f $MyInvocation.MyCommand, $ecmToUse, $lowResult, $highResult)
			
			if( $lowDamageBonus -lt $midDamageBonus)
			{
				$resultObject.crtResult = $lowResult
			}
			if( $highDamageBonus -lt $midDamageBonus -and $highDamageBonus -lt $lowDamageBonus)
			{
				$resultObject.crtResult = $highResult
			}
			if( $highDamageBonus -lt $midDamageBonus -or $lowDamageBonus -lt $midDamageBonus)
			{
				$resultObject.ecmUsed = $ecmToUse
				$ecmRemaining         = $ecmAvailable - $ecmToUse
				write-verbose ("  [{0,-20}] : ECM SUCCESS - Adjust result to $($resultObject.crtResult) and record ECM usage $($resultObject.ecmUsed), $($ecmAvailable - $resultObject.ecmUsed) left" -f $MyInvocation.MyCommand)
			}
		}
		else
		{
			write-verbose ("  [{0,-20}] : No effect on hit result, index adjustment dTL{1} - aTL{2} + ecm{3} = {4}" -f $MyInvocation.MyCommand, $dTL, $aTL, $ecmToUse, $driveDiffAdj)
		}
		$resultObject.ecmRemaining = $ecmRemaining
	}	
	
	
	#return
	$resultObject
}

#$aWeapon $aWeaponPower $aRoF $gameConfig.ComponentSpec $attackResult.crtResult $aAmmo 
function Calculate-WeaponDamage()
{
[CmdletBinding()]
	param(
		    $wepName
		  , $wepPwr
		  , $wepRoF
		  , $cSpec
		  , $result
		  , $wepAmmo
		  , $wepTL = 0
		  , $adjustDmgForTL = 1
	)
	if( (nullCoalesce($wepPwr, 0)) -eq 0)
	{
		#return
		0
	}
	else
	{
		$weaponSpec     = @($cSpec | ? { $_.Name -eq $wepName })[0]
		$wepAmmo        = nullCoalesce $wepAmmo, $wepName
		$ammoSpec       = @($cSpec | ? { $_.Name -eq $wepAmmo })[0]
		$damageBase     = $ammoSpec.Damage
		$TLBonus        = switch($adjustDmgForTL) {
			$true   { $wepTL; break; }
			$false  { 0     ; break; }
		}
		$hitBonus = Get-HitDamageBonus($result)
		$damageFinal = ($ammoSpec.Damage * $wepPwr * $wepRoF) + $TLBonus + $hitBonus
		#Power allocation to 
		$damageCalcHeader = "|Weapon | Ammo :(Base x Power x Shots) + TL? + Result      = Total |"
		$damageCalcHeader += "`n     " + ("-" * $damageCalcHeader.Length)
		$damageCalcVals   = "|{0,-6} | {1,-4} :({2,4} x {3,5} x {4,5}) + {5,3} + {6,2} ({7,-5})  = {8,5}" `
							-f $wepName, $wepAmmo, $damageBase, $wepPwr, $wepRoF, $TLBonus, $hitBonus, $result, $damageFinal
		write-verbose "CALCULATE-WEAPONDAMAGE: `n     $damageCalcHeader`n     $damageCalcVals"
		
		#return
		$damageFinal
	}
}

function Calculate-ScreenRating()
{
	[CmdletBinding()]
	param(
		$unit
		, $unitOrders
		, $TL_addTo_Screens=$true
	)
	
	$screenValue = $unitOrders.PowerAllocation.S
	if($TL_addTo_Screens) 
	{ 
		$screenValue += $unit.TL 
	}
	
	#return
	$screenValue
}

function Get-HitDamageBonus()
{
	[CmdletBinding()]
	param(
		$hitResult
	)
	#return
	switch -w ($hitResult) {
			"Escapes" { -999;                              break; }
			"Miss"    {  -99;                              break; }
			"Hit-*"   {   0-(($hitResult -split "\-")[1]); break; }
			"Hit*"    {   0+(($hitResult -split "\+")[1]); break; }
			Default   {    0;                              break; }
	}
}

function Get-DriveDiffIndex()
{
	[CmdletBinding()]
	param (
		$driveDiff
		, $maxDelta = 5
	)
	
	#return
	[Math]::Min([Math]::Max(-$maxDelta, $driveDiff), $maxDelta) + $maxDelta
}