using System;
using System.Collections.Generic;

public class GameUnit {
	public string   ID       { get;      }
	public string   Name     { get; set; }
	public UnitType unitType { get;      }
	
	public List<char> ComponentSpec; 
	
	public GameUnit() 
        : this(Guid.NewGuid().ToString(), "Uninitialized Unit", UnitType.SystemShip, null)
    {

    }
	
	public GameUnit (string unitId, String unitName, UnitType uType, List<char> components)
	{
		this.ID            = unitId;
		this.Name          = unitName;
		this.unitType      = uType;
		this.ComponentSpec = components ?? new List<char>();
	}
	
	public override String ToString()
	{
		return String.Format("Unit '{0}' of type '{1}' has [{2}] components ({3}) and ID {4}", this.Name, this.unitType, this.ComponentSpec.Count, String.Join(",", ComponentSpec), this.ID);
		
	}
}

public enum UnitType
{
	WarpShip,
	SystemShip,
	StarBase	
}