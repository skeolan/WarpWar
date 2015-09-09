[cmdletBinding()]
param(

)

#Game constants.
$const_combat_max_rounds = 3
$const_hull_damage_value = 1 #0 for "vanilla" rules; 1+ makes larger ships tougher than smaller ships with equal armor/shields/ecm.
$const_TL_add_to_BPLimit = 1 #0 for "vanilla" rules; 1+ alters the BP-by-size calculation from the static max-size spec to (sqrt(MaxSize) * (sqrt(maxSize) + TL -1))
$const_TL_add_to_damage  = 0 #1 for "vanilla" rules; 0 compensates for the increased damage capability that comes from having more BP for higher-TL ships.

#Initial Configuration.
$GameConfig=@"
{
	"ComponentSpecs": {
		  "PD"  : { "Name":"PD" , "BPCost": 1                                                     , "Type":"Power"      , "Info" : { "LongName":"Power/Drive"                , "Description":"Total effective strength of a ship's engines."                         } }
		, "B"   : { "Name":"B"  , "BPCost": 1    , "Damage" : 1, "RoF":1                          , "Type":"Weapon"     , "Info" : { "LongName":"Beams"                      , "Description":"Ability of a ship to project a beam of destructive energy at a target." } }
		, "C"   : { "Name":"C"  , "BPCost": 1                  , "RoF":3                          , "Type":"Weapon"     , "Info" : { "LongName":"Cannons"                    , "Description":"Launch Shells. Each Cannon may fire either 1, 2 or 3 Shells per combat round."        } }
		, "T"   : { "Name":"T"  , "BPCost": 1                  , "RoF":1                          , "Type":"Weapon"     , "Info" : { "LongName":"Tubes"                      , "Description":"Launch Missiles. Each Tube may launch one Missile per combat round."                  } }
		, "SH"  : { "Name":"SH" , "BPCost": 0.167, "Damage" : 1                                   , "Type":"Ammunition" , "Info" : { "LongName":"Shells"                     , "Description":"Fired by Cannons."                                                                    } }
		, "M"   : { "Name":"M"  , "BPCost": 0.333, "Damage" : 2                                   , "Type":"Ammunition" , "Info" : { "LongName":"Missiles"                   , "Description":"Fired by Tubes."                                                                      } }
		, "S"   : { "Name":"S"  , "BPCost": 1    , "Defense": 1                                   , "Type":"Defense"    , "Info" : { "LongName":"Screens"                    , "Description":"represent the ability of a ship to surround itself with a protective energy screen."  } }
		, "A"   : { "Name":"A"  , "BPCost": 0.5  , "Defense": 0                                   , "Type":"Defense"    , "Info" : { "LongName":"Armor"                      , "Description":"Ablative hull reinforcement."                                                         } }
		, "E"   : { "Name":"E"  , "BPCost": 1    , "Defense": 0, "ECM"    : 1                     , "Type":"Defense"    , "Info" : { "LongName":"ECM"                        , "Description":"Electronic countermeasures. ECM points alter attacking Missiles' effective Drive."    } }
		, "SR"  : { "Name":"SR" , "BPCost": 1                                                     , "Type":"Carry"      , "Info" : { "LongName":"Systemship Rack"            , "Description":"Let a Warpship carry Systemships."                                                    } }
		, "H"   : { "Name":"H"  , "BPCost": 0.1                                                   , "Type":"Carry"      , "Info" : { "LongName":"Hold"                       , "Description":"Contain cargo and/or BPs."                                                            } }
		, "R"   : { "Name":"R"  , "BPCost": 5                                                     , "Type":"Utility"    , "Info" : { "LongName":"Repair"                     , "Description":"Use BPs in Hold or from Star to repair self or others during the build/repair event." } }
		, "CP"  : { "Name":"CP" , "BPCost":15    , "Hull": 4, "maxSize":15                        , "Type":"Hull"       , "Info" : { "LongName":"Colony Pod"                 , "Description":"Establishes a new Colony when deployed."                                              } }
		, "SSB" : { "Name":"SSB", "BPCost": 7    , "Hull": 8, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Small Starbase Hull"        , "Description":"For bases BP 64(H 8) or smaller. (Defsat)"                                            } }
		, "MSB" : { "Name":"MSB", "BPCost":13    , "Hull":12, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Medium Starbase Hull"       , "Description":"For bases BP144(H12) or smaller. (Station)"                                           } }
		, "LSB" : { "Name":"LSB", "BPCost":25    , "Hull":20, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Large Starbase Hull"        , "Description":"For bases BP400(H20) or smaller. (Fortress)"                                          } }
		, "SWG" : { "Name":"SWG", "BPCost": 3    , "Hull": 3, "maxSize":4 , "PDPerMP":1           , "Type":"Hull"       , "Info" : { "LongName":"Small Warp Generator Hull"  , "Description":"For ships BP  9(H 3) or smaller. (Escort)"                                            } }
		, "MWG" : { "Name":"MWG", "BPCost": 6    , "Hull": 6, "maxSize":4 , "PDPerMP":2           , "Type":"Hull"       , "Info" : { "LongName":"Medium Warp Generator Hull" , "Description":"For ships BP 36(H 6) or smaller. (Cruiser)"                                           } }
		, "LWG" : { "Name":"LWG", "BPCost": 9    , "Hull": 8, "maxSize":4 , "PDPerMP":3           , "Type":"Hull"       , "Info" : { "LongName":"Large Warp Generator Hull"  , "Description":"For ships BP 64(H 8) or smaller. (Capital)"                                           } }
		, "GWG" : { "Name":"GWG", "BPCost":12    , "Hull":10, "maxSize":4 , "PDPerMP":3           , "Type":"Hull"       , "Info" : { "LongName":"Giant Warp Generator Hull"  , "Description":"For ships BP100(H10) or smaller. (Supercapital)"                                      } }
		, "SSS" : { "Name":"SSS", "BPCost": 0    , "Hull": 3, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Small System Ship Hull"     , "Description":"For ships BP  9(H 3) or smaller. (Fighter/Escort)"                                    } }
		, "MSS" : { "Name":"MSS", "BPCost": 2    , "Hull": 6, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Medium System Ship Hull"    , "Description":"For ships BP 36(H 6) or smaller. (Cruiser)"                                           } }
		, "LSS" : { "Name":"LSS", "BPCost": 4    , "Hull": 8, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Large System Ship Hull"     , "Description":"For ships BP 64(H 8) or smaller. (Capital)"                                           } }
		, "GSS" : { "Name":"GSS", "BPCost": 6    , "Hull":10, "maxSize":4                         , "Type":"Hull"       , "Info" : { "LongName":"Giant System Ship Hull"     , "Description":"For ships BP100(H10) or smaller. (Supercapital)"                                      } }
	}
}
"@

#Template and combatant warship specs                          
$templateInfoSpec       = "ID=TS1-01-001 Name=Template_Ship Owner=Template_Owner Location=COORD[-,-] TL=1 Universe=Reign_Of_Stars Valid=??? Racks= Cargo="
$templateAttrSpec       = "PD=0 B=0 S=0 T=0 M=0 SR=0 C=0 SH=0 A=0 E=0 H=0 R=0 CP=0 SWG=0 MWG=0 LWG=0 SB=0 _BPCost=0 _MaxSize=0 _PDPerMP=0 _Hull=0"
$templateSpec           = ("{0} -- {1}" -f $templateInfoSpec, $templateAttrSpec)
$shipSpecs              = @(
                             "{0} -- {1}" -f "ID=IWS-01-001 Name=Gladius_001 Owner=Empire Location=COORD[1,1] TL=2", "SWG=1 MWG=1 PD=4 B=2 S=1"
							,"{0} -- {1}" -f "ID=ISS-0A-00A Name=Portero_001 Owner=Empire Location=COORD[1,1] TL=1 Cargo=12xBP,Space_Marine_Terminators(5)", "SSS=1 PD=6 H=10 S=2" 
                            ,"{0} -- {1}" -f "ID=RWS-01-001 Name=Vulpine_001 Owner=Rebels Location=COORD[2,2] TL=2 Racks=RSS-0A-00A,RSB-0A-001,BOGUS", "SWG=1 PD=2 T=1 S=1 M=3 SR=1"
                            ,"{0} -- {1}" -f "ID=RSS-0A-00A Name=Kitsune_00A Owner=Rebels Location=Racked TL=2", "SSS=1 PD=5 B=4 S=1"
							,"{0} -- {1}" -f "ID=RSB-0A-001 Name=Warrens_00A Owner=Rebels Location=Racked", "SSB=1 PD=2 B=1 S=1"
						)
						
						
$GameData = $GameConfig | ConvertFrom-Json
$GameData

#region examples for traversing the json object
write-Verbose "WEAPONS"
$weps = @("B", "C", "T")
#should be "select everything in ComponentSpec that has a RoF property"
foreach ($w in $weps)
{
	$wep = $ComponentData.ComponentSpecs.$w
	write-verbose ("    {0,-25} {1}`n" -f  $wep.Info.LongName, $wep.Info.Description)
	write-verbose ("    {0,-25} {1}"   -f " ", $wep)
	
}

write-Verbose "AMMO"

write-Verbose "DEFENSES"

write-Verbose "DRIVE/HULL"

write-Verbose "CARRY"

write-Verbose "AUXILIARY"

#endregion
