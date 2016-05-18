using System;
using System.Diagnostics;
using System.Collections.Generic;
using wwCoreCLR.Game;

public class Program
{
	public static void Main(string[] args)
	{
		Debug.Print("Begin combat!");

        var gameUnits = InitTestUnits();
        var turnCount = 2;
        for (int i=1; i<= turnCount; i++) {
            Debug.Print(" -- Begin turn {0} -- ", i);
        }
        Debug.Print("Combat completed!");

    }

    public static List<Unit> InitTestUnits() 
    {
        var unit1Spec = "S,B,B,P,P,P,SS";
        var unit2Spec = "S,S,B,B,P,P,SS";
        var defaultUnit = new Unit();
        var unit1 = defaultUnit.Clone("Ansible-I");
        unit1.setComponentSpec(unit1Spec);
        var unit2 = unit1.Clone();

        Console.WriteLine("INFO: {0}", defaultUnit.ToString());
        Debug.Print("INFO: {0}", defaultUnit.ToString());

        Console.WriteLine("INFO: {0}", unit1.ToString());
        Debug.Print("INFO: {0}", unit1.ToString());

        Console.WriteLine("INFO: {0}", unit2.ToString());
        Debug.Print("INFO: {0}", unit2.ToString());

        Debug.Print("Re-Spec Unit 2...");
        unit2.Name = "Ansible-II";
        unit2.setComponentSpec(unit2Spec);
        Console.WriteLine("INFO: {0}", unit2.ToString());
        Debug.Print("INFO: {0}", unit2.ToString());

        return new List<Unit>() { unit1, unit2 };
    }
}
