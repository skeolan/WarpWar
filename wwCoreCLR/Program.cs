using System;
using System.Diagnostics;

public class Program
{
	public static void Main(string[] args)
	{
		Console.WriteLine("Hello World!");

        var unitSpec = "SBBPPP";
		var defaultUnit = new GameUnit();
        defaultUnit.ComponentSpec.AddRange(unitSpec.ToCharArray());

        Console.WriteLine("INFO: {0}", defaultUnit.ToString());
        Debug.WriteLine("INFO: {0}", defaultUnit.ToString());
        
	}
}
