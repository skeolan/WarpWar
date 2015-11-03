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
	)
	
	$weaponSpec  = @($cSpec | ? { $_.Name -eq $wepName })[0]
	$wepAmmo     = nullCoalesce $wepAmmo, $wepName
	$ammoSpec    = @($cSpec | ? { $_.Name -eq $wepAmmo })[0]
	$damageBase  = $ammoSpec.Damage
	$damageBonus = switch($result) {
		"Hit"   {0; break;}
		"Hit+1" {1; break;}
		"Hit+2" {2; break;}
	}
	$damageFinal = ($ammoSpec.Damage * $wepPwr * $wepRoF) + $damageBonus
	#Power allocation to 
	write-verbose ("CALCULATE-WEAPONDAMAGE: Weapon '{0}' /ammo '{1}'; base damage [{2}]; attack power [{3}]; Shots [{4}]; Result '{5}'(+{6}) = {7}" `
                	-f $wepName, $wepAmmo, $damageBase, $wepPwr, $wepRoF, $result, $damageBonus, $damageFinal)
	$damageFinal
}