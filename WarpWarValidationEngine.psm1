#WarpWarValidationEngine

function Validate-Orders()
{
	[CmdletBinding()]
	param(
		  $attacker
		, $defender
		, $attackerOrders
		, $defenderOrders		
	)

	$true
}


function Validate-Unit()
{
	[cmdletBinding()]
	param (
		$unit
	)
	
	$result = @()
	
	#SRUsed - SRAvail should be nonnegative
	#HUsed  - HAvail  should be nonnegative
	#BPMax  - BPCost  should be nonnegative
	
	#EffectiveAttrs should each be nonnegative
	
	#Units in your Racks should have Size no larger than you
	#Units in your Racks should have you as their Location
	#Units in your Racks should have no units in their Racks
	
	#Units in your Cargo should have no units in their Racks

	$result
}

