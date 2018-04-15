class CfgPatches
{
	class Auto_Medic
	{
		units[] = {"Auto_Medic"};
		requiredVersion = 1.0;
		requiredAddons[] = {"A3_Modules_F"};
	};
}; 
class CfgFunctions 
{
	class AM
	{
		class AutoMedic
		{
			file = "\Auto_Medic\functions";
			class autoMedicInit{postInit=1};
		};
	};
};