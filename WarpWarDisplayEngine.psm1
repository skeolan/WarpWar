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

function Summarize-CombatResult()
{
	[CmdletBinding()]
	param( $CombatResult )
	foreach($key in ($CombatResult.Keys | sort)) 
	{ 
		$resultHeader = "$key - $($CombatResult[$key].Count) attack(s)" 
		
		""
		$resultHeader
		"-" * $resultHeader.Length

		foreach($atk in $CombatResult[$key]) 
		{ 
			("{0,-10} {1,-7} {2,-10} with {3, 3}/{4, -3} for {5,4} ( {6}, {7}, {8} ) ECM {9} used, {10} remaining" `
			-f $atk.attacker, $atk.crtResult, $atk.target, $atk.weapon, $atk.ammo, $atk.damage, $atk.attackType, $atk.crtResult, $atk.turnResult, $atk.ecmUsed, $atk.ecmRemaining); 
		} 
		"-" * $resultHeader.Length
	}
}


function printShipInfo
{
    [cmdletBinding()]
	param(
		  $s
		, [switch] $includeZeroes
		, [Decimal] $infoEntryLeftSegmentLen  =20
		, [Decimal] $lineEntryLeftSegmentLen  =19
		, [Decimal] $lineEntryRightSegmentLen =25
		, [Decimal] $lineEntryFullLen         =45
	) 
	
	if($includeZeroes -eq $true)
	{
		WRITE-DEBUG ("{0}{1} -- including zeroes!" -f $s.Name, $s.ID )
	}
	else
	{
		WRITE-DEBUG ("{0}{1} -- EXcluding zeroes" -f $s.Name, $s.ID )
	}
	
	
	#Header
	("| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen} |" -f $s.ID, $s.Name )
	"|-{0,-$infoEntryLeftSegmentLen}--{1, -$lineEntryFullLen}-|" -f (("-"*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))
	#Excluded info fields -- fields which either need additional special handling, or aren't to be displayed
	$exclInfoFields = ("ID", "Name", "Cargo", "Components", "Damage", "DerivedAttrs", "EffectiveAttrs", "HAvail", "HUsed", "MP", "PDPerMP", "SRAvail", "SRUsed", "Location", "TurnOrders", "PowerAllocation", "PowerUsed", "Racks", "Valid", "ValidationResult")
	#Ordered info fields
	$orderedInfoFields = ("Owner", "Universe", "TL", "BPCost", "BPMax", "Size", "MP") 
	foreach ($infoKey in $orderedInfoFields)
	{ 
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen} |" -f ($infoKey, (nullCoalesce $s.$infoKey, 0))
	}
	
	#Unordered info fields - just display alphabetically
    $s.GetEnumerator() | sort key | foreach { 
		if(-not $orderedInfoFields.Contains($_.Key) -and -not $exclInfoFields.Contains($_.Key) -and ( $includeZeroes -eq $true -or $_.Value -ne 0) ) 
		{ 
			"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen} |" -f $_.Key, $_.Value 
		} 
	}
	
	#Complex info fields
		write-debug "Location"
		print-LocationDetail  -title "Location"   -location $s.Location

		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen}-|" -f ((" "*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))

		write-debug "Components"
		print-ComponentDetail -title "Components" -collection $s.Components -effectiveCollection $s.EffectiveAttrs -damageCollection $s.Damage -powerCollection $s.PowerAllocation -includeZeroes $includeZeroes 
		write-debug "Cargo"
		print-ListDetail      -title "Cargo"      -collection $s.Cargo -count $s.HUsed  -capacity $s.HAvail
		write-debug "Racks"		
		print-ListDetail      -title "Racks"      -collection $s.Racks -count $s.SRUsed -capacity $s.SRAvail
		write-debug "EffectiveAttrs (incl damage annotations)"
		write-debug "ValidationResult (incl 'Valid' ruling)"
		
	#Footer
	"|-{0,-$infoEntryLeftSegmentLen}--{1, -$lineEntryFullLen}-|" -f (("-"*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))
}

function print-ComponentDetail()
{
	[CmdletBinding()]
	param(
		  $collection
		, $damageCollection         = $null
		, $effectiveCollection      = $null
		, $powerCollection          = $null
		, $title                    = "Components"
		, $includeZeroes            = $false
		, $infoEntryLeftSegmentLen  = 20
		, $lineEntryLeftSegmentLen  = 19
		, $lineEntryRightSegmentLen = 25
		, $lineEntryFullLen         = 45
	)
	
	$compInfoHeader="Max | Dmg | Eff | Pwr "		

	if($collection.Count -gt 0 -or $includeZeroes)
	{
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen } {2, -$lineEntryRightSegmentLen} |" -f "$title", "Name (#)", $compInfoHeader
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryFullLen}-|" -f ((" "*$infoEntryLeftSegmentLen), ("-"*$lineEntryFullLen))

	}
	
	foreach ($entry in $collection.GetEnumerator())
	{
		write-debug $entry
		if($entry.Value -eq 0 -and -not $includeZeroes)
		{
			write-debug "$($entry.Key) is zero, skipping)"
			continue
		}
		
		if($entry.Value -ne $null)
		{
			$eKey         = $entry.Key
			$eVal         = $entry.Value
			$eDmgTxt      = (nullCoalesce $damageCollection.$eKey   , 0)
			$eEffTxt      = (nullCoalesce $effectiveCollection.$eKey, ($eVal - $eDmgTxt))
			$eSpecTxt     = $eEffTxt + $eDmgTxt
			$ePwrTxt      = (nullCoalesce ($powerCollection | ? { $_.Key -eq "$eKey" }).Value, 0)
			$eRightBuffer = $lineEntryRightSegmentLen - $compInfoHeader.Length
			
			if($eVal -ne 1)
			{
				$eKeyTxt = "{0,-4} ({1})" -f $eKey, $eVal
			}
			else
			{
				$eKeyTxt = $eKey
			}
			
			"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen} {2, 3} | {3, 3} | {4,3} | {5,3} {6,$eRightBuffer} |" -f "", $eKeyTxt, $eSpecTxt, $eDmgTxt, $eEffTxt, $ePwrTxt, ""
		}
	}
	
}

function print-LocationDetail()
{
	[CmdletBinding()]
	param(
		  $location
		, $title
		, $infoEntryLeftSegmentLen  = 20
		, $lineEntryLeftSegmentLen  = 19
		, $lineEntryRightSegmentLen = 25
		, $lineEntryFullLen         = 45
	)

	if($location -ne $null -or $includeZeroes)
	{
		$lineItemTitle = ""
		$lineItemInfo  = ""
		
		#Valid Possibilities: a) unit has a bare X,Y coordinate or System as its Location
		#                     b) unit is in Racks or Cargo - its parent is of type (a)
		#                     c) unit is in Cargo - its parent is in Racks, and ITS parent is of Type (a)
		#                     d) ???
		$xCoord = (nullCoalesce($location.X, $location.Location.X, $location.Location.Location.X, "?"))
		$yCoord = (nullCoalesce($location.Y, $location.Location.Y, $location.Location.Location.Y, "?"))

		$lineItemTitle = "{0}" -f (nullCoalesce $location.Name, "")
		$lineItemInfo = ((("<{0},{1}>" -f $xCoord, $yCoord) -join " ").Trim())
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen} {2, -$lineEntryRightSegmentLen} |" -f "$title", $lineItemTitle, $lineItemInfo
	}
}

function print-ListDetail()
{
	[CmdletBinding()]
	param(
		  $collection
		, $title
		, $count
		, $capacity
		, $includeZeroes
		, $infoEntryLeftSegmentLen  = 20
		, $lineEntryLeftSegmentLen  = 19
		, $lineEntryRightSegmentLen = 25
		, $lineEntryFullLen         = 45
	)
	
	write-debug "detailing $($collection.Count) list items..."
	
	if($collection.Count -gt 0 -or $includeZeroes)
	{
		$qtyHeader=""
		if($count -ne $null)
		{
			$qtyHeader = "($count"
			if($capacity -ne $null)
			{
				$qtyHeader += "/$capacity"
			}
			$qtyHeader += ")"
		}
		
		"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen}-{2, $lineEntryRightSegmentLen} |" -f "$title $qtyHeader", ("-"*$lineEntryLeftSegmentLen), ("-"*$lineEntryRightSegmentLen)
		foreach ($entry in $collection.GetEnumerator())
		{
			write-debug $entry
			if($entry.Value -eq 0 -and -not $includeZeroes)
			{
				write-debug "$($entry.Key) is zero, skipping)"
				continue
			}
			
			$lineItemTitle = ""
			$lineItemInfo  = ""
			
			if ($entry.GetType() -eq "string".GetType()) #simple string entry
			{
				$lineItemTitle = $entry
			}
			if ($entry.Name -ne $null) #Named-object reference entry
			{
				$lineItemTitle = "{0}" -f $entry.Name
				if($entry.Qty -ne $null -and $entry.Qty -gt 1)
				{
					$lineItemTitle = "{0}x {1}" -f $entry.Qty, $lineItemTitle
				}
				
				if($entry.Size -ne $null -or $entry.Qty -ne $null)
				{
					$lineItemInfo += "{0, $lineEntryRightSegmentLen}" -f ("("+((nullCoalesce $entry.Size, 1) * (nullCoalesce $entry.Qty, 1))+")")
				}
				else
				{
					$lineItemInfo += " {0, $lineEntryRightSegmentLen}" -f ""
				}
			}
			
			#last-ditch, probably won't be pretty
			if ($lineItemTitle -eq "")
			{
				$lineItemTitle="{0}" -f "", $entry
			}
			
			"| {0,-$infoEntryLeftSegmentLen}| {1, -$lineEntryLeftSegmentLen} {2, $lineEntryRightSegmentLen} |" -f "", $lineItemTitle, $lineItemInfo
		}
	}
}

