using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace wwCoreCLR.GameRuleSet {
    /// <summary>
    /// Interface for component *specifications*, i.e. the rules and stats about how each component works within the current ruleset.
    /// </summary>
    public interface IComponentSpec {

    }

    /// <summary>
    /// Generic data/behaviors shared by all components
    /// </summary>
    public abstract class GenericComponentSpec : IComponentSpec {
        public GenericComponentSpec() { }

    }

    /// <summary>
    /// Components which can attack and/or do damage to a GameUnit
    /// </summary>
    public class WeaponSpec : GenericComponentSpec {

    }

    /// <summary>
    /// Components which serve some other role for a GameUnit
    /// </summary>
    public class MiscComponentSpec : GenericComponentSpec {

    }
}