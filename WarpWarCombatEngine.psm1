#WarpWarCombatEngine


function execute-TurnOrder()
{
	[cmdletBinding()]
	param (
		  $attacker
		  , $turn
		  , $gameConfig
	)
	
	
	
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
	
	
	write-verbose ( "[ENGINE:Resolve-Attack]     Orders: {0} : {1} at Drive {2}" -f $a.Name, $ao.Tactic, $ao.PowerAllocation.PD)
	$crt      = $gameConfig.CombatResults
	$maxDelta = NullCoalesce($gameConfig.Constants.Combat_max_DriveDiff, 5)

	$a        = $attacker
	$aName    = $a.Name
	$ao       = $attackerOrders
	$aTL      = [Math]::Max((NullCoalesce($attack.TL, $ao.TL, $a.TL, 1)), 1)
	$apo      = NullCoalesce($ao.PowerAllocation, $a.PowerAllocation)
	$aTactic  = NullCoalesce($ao.Tactic, "??")
	$aDrv     = NullCoalesce($attack.WeaponDrive, $apo.PD, 0)
	$aECM     = NullCoalesce($apo.E, 0)

	$d             = $defender
	$dName         = $d.Name
	$do            = $defenderOrders
	$dTL           = [Math]::Max((NullCoalesce($do.TL, $d.TL, 1)), 1)
	$dpo           = nullCoalesce($do.PowerAllocation, $d.PowerAllocation)
	$dTactic       = nullCoalesce ($do.Tactic, "??")
	$dDrv          = nullCoalesce ($dpo.PD, -1)	
	$dECMUsed      = nullCoalesce ($do.EcmUsed, 0)
	$dECM          = nullCoalesce ($dpo.E , 0)
	$dECMAvailable = [MATH]::MAX($dECM - $dECMUsed, 0)
	          
	$aWeapon  = nullCoalesce ($attack.Weapon, "??")
	$aRoF     = nullCoalesce ($attack.RoF, 1)
	$aAmmo    = nullCoalesce ($attack.WeaponAmmo, $aWeapon)
	$aTactic  = nullCoalesce ($ao.Tactic, "??")
	$aWeaponPower  = nullCoalesce ($attack.Power, $apo.$aWeapon, 0)
	
	$driveDiff = $aDrv - $dDrv
	
	$attackResult = @{
		"attacker"     = $attacker.ID;
		"weapon"       = $aWeapon;
		"ammo"         = $aAmmo;
		"target"       = $d.ID;
		"turnResult"   = "Continue";
		"crtResult"    = "";
		"damage"       = 0;
		"attackType"   = "direct";
		"ecmUsed"      = $dECMUsed;
		"ecmRemaining" = $dECMAvailable;
 	}
	
	
	write-verbose ("[ENGINE:Resolve-Attack]     - [{0}]({1}) with {2} shot(s) and power [$aWeaponPower] from {3} - {4} at speed {5} vs [{6}]({7}) {8} at speed {9} and ECM {10}/{11} -- TL {12} vs {13}" `
	               -f $a.Name, $a.ID, $aRoF, $aWeapon, $aTactic, $aDrv, $dName, $attack.Target, $dTactic, $dDrv, $dECMUsed, $dECMAvailable, $aTL, $dTL)
	if((nullCoalesce($attack.WeaponDrive, -1)) -ne -1) 
	{
		$attackResult.attackType = "indirect" 
	}
	
	$attackResult.crtResult = Calculate-AttackResult $aTactic $dTactic $driveDiff $crt $maxdelta
	if($dECMAvailable -gt 0 -and $attackResult.crtResult -like "Hit*" -and $attackResult.attackType -eq "indirect")
	{
		$attackResult = Calculate-ECMResult $aTactic $dTactic $driveDiff $crt $attackResult $maxDelta $dTL $aTL
	}

	if($attackResult.crtResult -ne "Miss" -and $attackResult.crtResult -ne "Escapes")
	{
		$attackResult.Damage = Calculate-WeaponDamage $aWeapon $aWeaponPower $aRoF $gameConfig.ComponentSpecs $attackResult.crtResult $aAmmo $aTL ($gameConfig.Constants.TL_addTo_Damage -gt 0)
		
	}
		
	
	if($attackResult.Damage -ne 0)
	{
		write-verbose ( "{0}Target hit for {1} damage!" -f "[ENGINE:Resolve-Attack]     ", $attackResult.Damage)
	}
	if($wepResult -eq "Miss")
	{
		write-verbose ("{0} {1} attack with {2} missed {3} !" -f "[ENGINE:Resolve-Attack]     ", $attacker.Name, $wepName, $defender.Name)
	}
	if($wepResult -eq "Escapes")
	{
		write-verbose ("{0} {1} attack with {2} missed and permitted {3} to escape!" -f "[ENGINE:Resolve-Attack]     ", $attacker.Name, $wepName, $defender.Name)
		$attackResult.turnResult="Escapes"
	}
	
	$attackResult
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
	  $aTac
	, $dTac
	, $driveDiff
	, $crt
	, $resultObject 
	, $maxDelta 
	, $dTL 
	, $aTL
 )
	
	$ecmToUse               = 0
	$ecmAvailable           = $resultObject.ecmRemaining
	
	while($resultObject.crtResult -like "Hit*" -and ++$ecmToUse -le $resultObject.ecmRemaining)
	{
		write-verbose ("  [{0,-20}] : evaluate using ECM {1}" -f $MyInvocation.MyCommand, $ecmToUse)
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
				$resultObject.ecmUsed      = $ecmToUse
				$resultObject.ecmRemaining = $ecmAvailable - $resultObject.ecmUsed
				write-verbose ("  [{0,-20}] : ECM SUCCESS - Adjust result to $($resultObject.crtResult) and record ECM usage $($resultObject.ecmUsed), $($resultObject.ecmRemaining) left" -f $MyInvocation.MyCommand)
			}
		}
		else
		{
			write-verbose ("  [{0,-20}] : No effect on hit result, index adjustment dTL{1} - aTL{2} + ecm{3} = {4}" -f $MyInvocation.MyCommand, $dTL, $aTL, $ecmToUse, $driveDiffAdj)
		}
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