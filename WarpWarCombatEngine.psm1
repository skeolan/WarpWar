#WarpWarCombatEngine

function Calculate-CombatResult()
{
 [CmdletBinding()]
 param(
	  $aTac
	, $dTac
	, $aDrive
	, $dDrive
	, $CRT           #Combat Results Table lookup object, structured for lookups like AttackerTactic.DefenderTactic[DriveDiff]
	, $maxDelta      #Maximum absolute value of drive difference - all out-of-bounds results are Miss or Escapes
	, $aTL           #TL and ECM not yet implemented (for missiles)
	, $dTL           #TL and ECM not yet implemented (for missiles)
	, $dECM          #TL and ECM not yet implemented (for missiles)
	)
	
	$driveDiff       = $aDrive - $dDrive
	$driveDiffIndex  = [Math]::Min([Math]::Max(-$maxDelta, $driveDiff), $maxDelta) + $maxDelta
	
	write-verbose("[ENGINE:Calculate-CombatResult]          {0} vs {1} at Drive {2}-{3}=>{4} (read as {5}) = {6}" -f $aTac, $dTac, $aDrive, $dDrive, $driveDiff, $driveDiffIndex, $CRT.$aTac.$dTac[$driveDiffIndex])
	
	#return
	$CRT.$aTac.$dTac[$driveDiffIndex]
}

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
		$attackResult = resolve-Attack $gameConfig $attacker $ao $attack
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
		, $ao
		, $attack
	)
	
	
	write-verbose ( "[ENGINE:Resolve-Attack]     Orders: {0} : {1} at Drive {2}" -f $a.Name, $ao.Tactic, $ao.PowerAllocation.PD)
	$crt      = $gameConfig.CombatResults
	$maxDelta = NullCoalesce($gameConfig.Constants.Combat_max_DriveDiff, 5)

	$a        = $attacker
	$aName    = $a.Name
	$aTL      = [Math]::Min((NullCoalesce($a.TL, 1)), 1)
	$ao       = $ao
	$apo      = NullCoalesce($ao.PowerAllocation, $a.PowerAllocation)
	$aTactic  = NullCoalesce($ao.Tactic, "??")
	$aDrv     = NullCoalesce($attack.WeaponDrive, $apo.PD, 0)
	$aECM     = NullCoalesce($apo.E, 0)

	$d       = $gameConfig.ShipSpecs | where {$_.ID -eq $attack.Target}
	$dName   = $d.Name
	$dTL     = [Math]::Min((NullCoalesce($d.TL, 1)), 1)
	$do      = $d.TurnOrders[$turn-1]
	$dpo     = nullCoalesce($do.PowerAllocation, $d.PowerAllocation)
	$dTactic = nullCoalesce ($do.Tactic, "??")
	$dDrv    = nullCoalesce ($dpo.PD, -1)	
	$dECM    = nullCoalesce ($dpo.E , 0)
	
	$aWeapon = nullCoalesce ($attack.Weapon, "??")
	$aRoF    = nullCoalesce ($attack.RoF, 1)
	$aAmmo   = nullCoalesce ($attack.WeaponAmmo, $aWeapon)
	$aTactic = nullCoalesce ($ao.Tactic, "??")
	$aWeaponPower  = nullCoalesce ($attack.Power, $apo.$aWeapon, 0)
	
	$attackResult = @{
		"attacker"     = $attacker.ID;
		"weapon"       = $aWeapon;
		"ammo"         = $aAmmo;
		"target"       = $d.ID;
		"turnResult"   = "Continue";
		"crtResult"    = "";
		"damage"       = 0;
		"attackType"   = "direct";
	}
	
	if((nullCoalesce($attack.WeaponDrive, 0)) -ne 0) 
	{
		$attackResult.attackType = "indirect"
	}
	
	write-verbose ("[ENGINE:Resolve-Attack]     - [{0}]({1}) with {2} shot(s) from {3} - {4} at speed {5} vs [{6}]({7}) {8} at speed {9} and ECM {10} -- TL {11} vs {12}" -f $a.Name, $a.ID, $aRoF, $aWeapon, $aTactic, $aDrv, $dName, $attack.Target, $dTactic, $dDrv, $dECM, $aTL, $dTL)
	
	$attackResult.crtResult = Calculate-CombatResult $aTactic $dTactic $aDrv $dDrv $crt $maxdelta $aTL $dTL $dECM
	if($attackResult.crtResult -ne "Miss" -and $attackResult.crtResult -ne "Escapes")
	{
		$attackResult.Damage = Calculate-WeaponDamage $aWeapon $aWeaponPower $aRoF $gameConfig.ComponentSpecs $attackResult.crtResult $aAmmo $aTL ($gameConfig.Constants.TL_addTo_Damage -gt 0)
		if($attackResult.Damage -ne 0)
		{
			write-verbose ( "{0}Target hit for {1} damage!" -f "[ENGINE:Resolve-Attack]     ", $attackResult.Damage)
		}
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
	
	$weaponSpec     = @($cSpec | ? { $_.Name -eq $wepName })[0]
	$wepAmmo        = nullCoalesce $wepAmmo, $wepName
	$ammoSpec       = @($cSpec | ? { $_.Name -eq $wepAmmo })[0]
	$damageBase     = $ammoSpec.Damage
	$TLBonus        = switch($adjustDmgForTL) {
		$true   { $wepTL; break; }
		$false  { 0     ; break; }
	}
	$hitBonus = switch($result) {
		"Hit"   {0; break;}
		"Hit+1" {1; break;}
		"Hit+2" {2; break;}
	}
	$damageFinal = ($ammoSpec.Damage * $wepPwr * $wepRoF) + $TLBonus + $hitBonus
	#Power allocation to 
	$damageCalcHeader = "|Weapon | Ammo :(Base x Power x Shots) + TL? + Result      = Total |"
	$damageCalcHeader += "`n     " + ("-" * $damageCalcHeader.Length)
	$damageCalcVals   = "|{0,-6} | {1,-4} :({2,4} x {3,5} x {4,5}) + {5,3} + {6,2} ({7,-5})  = {8,5}" `
	                    -f $wepName, $wepAmmo, $damageBase, $wepPwr, $wepRoF, $TLBonus, $hitBonus, $result, $damageFinal
	write-verbose "CALCULATE-WEAPONDAMAGE: `n     $damageCalcHeader`n     $damageCalcVals"
	$damageFinal
}