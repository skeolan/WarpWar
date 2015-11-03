#WarpWarDisplayEngine

function summarize-ComponentData()
{
	[cmdletBinding()]
	param( $compData )

	$weps = $compData | ? { $_.CompType -eq "Weapon"     } # or $_.RoF -ne $null if you want to be fancy
	$ammo = $compData | ? { $_.CompType -eq "Ammunition" }
	$defs = $compData | ? { $_.CompType -eq "Defense"    }
	$hull = $compData | ? { $_.CompType -eq "Hull"       }
	$bays = $compData | ? { $_.CompType -eq "Carry"      }
	$util = $compData | ? { $_.CompType -eq "Utility" -or $_.CompType -eq  "Power" }

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
