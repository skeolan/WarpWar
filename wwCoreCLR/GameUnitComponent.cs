using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using wwCoreCLR.GameRuleSet;

namespace wwCoreCLR.GameUnitComponent
{
    public class GameUnitComponent {
        IComponentSpec componentSpec { get; set; }
        string abbreviation;
    }
}
