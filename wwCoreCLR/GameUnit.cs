using System;
using System.Collections.Generic;

namespace wwCoreCLR.Game {

    public class Unit {
	    public string   ID       { get;      }
	    public string   Name     { get; set; }
	    public UnitType unitType { get;      }
	
	    public List<string> ComponentSpec { get; private set; }


    #region constructors
        public Unit() 
            : this(Guid.NewGuid().ToString(), "Uninitialized Unit", UnitType.SystemShip, (List<string>)null)
        {

        }

        internal Unit Clone() {
            return this.Clone(null);
        }

        internal Unit Clone(string newName) {
            var cloneObject = new Unit(Guid.NewGuid().ToString(), newName ?? "Clone of "+this.Name, this.unitType, (List<string>)null);
            cloneObject.setComponentSpec(this.ComponentSpec);
            return cloneObject;
        }

        public Unit (string unitId, String unitName, UnitType uType, List<string> components)
	    {
		    this.ID            = unitId;
		    this.Name          = unitName;
		    this.unitType      = uType;
		    this.ComponentSpec = components ?? new List<string>();
	    }

        public Unit (string unitID, string unitName, UnitType unitType, string components)
            : this(unitID, unitName, unitType, (List<string>)null) 
        {
            setComponentSpec(components);
        }
    #endregion

    #region special componentSpec setters
        public void setComponentSpec(string components) {
            setComponentSpec((components ?? "").Split(' ', ',', ':', '-'));
        }

        public void setComponentSpec(string[] components) {
            setComponentSpec(new List<string>(components));
        }

        public void setComponentSpec(List<string> components) {
            this.ComponentSpec = components;
        }
    #endregion

        public override String ToString()
	    {
		    return String.Format("Unit '{0, -30}' of type '{1}' has [{2}] components ({3}) and ID {4}", this.Name, this.unitType, this.ComponentSpec.Count, String.Join(",", ComponentSpec), this.ID);
		
	    }
    }

    public enum UnitType
    {
	    WarpShip,
	    SystemShip,
	    StarBase	
    }
}