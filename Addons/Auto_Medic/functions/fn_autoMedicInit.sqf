Auto_Medic_Running = false;
Auto_Medic_Damage_Threshold = .3;
Auto_Medic_Incapacitation_Threshold = .8;
Auto_Medic_Need_Radio = true;

Auto_Medic_Init = {	
	[] call Auto_Medic_Start; 
};


Auto_Medic_Start = {
    Auto_Medic_Running = true;
	if !(isNil "Auto_Medic_Action_On") then { (player) removeAction Auto_Medic_Action_On; };   
    Auto_Medic_Action_Off = (player) addAction ["Auto-Medic OFF", "[] spawn Auto_Medic_Stop; ", [], 1, false, true, "", "true"];
	
	[] spawn {
		while {Auto_Medic_Running} do {		
			_injured = [] call Auto_Medic_GetMostInjured; 			 			 
			[] spawn Auto_Medic_IncapacitateAiUnits;
			
			if (!isNull _injured) then {				
				[_injured] spawn Auto_Medic_Heal; 
			}
			else {
			
			};			
			sleep 2;
		};
	};
};

Auto_Medic_Stop = {
    Auto_Medic_Running = false;
	if !(isNil "Auto_Medic_Action_Off") then { (player) removeAction Auto_Medic_Action_Off; };
    Auto_Medic_Action_On = (player) addAction ["Auto-Medic ON", "[] spawn Auto_Medic_Start; ", [true], 1, false, true, "", "true"]; 
	[] call Auto_Medic_ResetUnitVariables;
};
 
Auto_Medic_HasMedic = { 
	_hasMedic = false;
	{
		if (!(isPlayer _x) && alive _x) then {
			_hasMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _x >> "attendant" ) isEqualTo 1;
			if(_hasMedic) exitWith{};
		};
	} forEach units group player;
	_hasMedic;
}; 

Auto_Medic_GetMedic = { 
	_medic = objNull;	
	{
		if (!(isPlayer _x) && alive _x) then {
			_isMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _x >> "attendant" ) isEqualTo 1;				
			if(_isMedic) then {
				_medic = _x;
			}
		};
	} forEach units group player;
	
	_medic;
}; 

Auto_Medic_IncapacitateAiUnits = {		
	if(!Auto_Medic_Running) exitWith {};
	{	
		_damage = getDammage _x; 
		_isPlayer = isPlayer _x;
		_isMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _x >> "attendant" ) isEqualTo 1;
		_isAlive = alive _x;
		_isIncapacitated = _x getVariable["Incapacitated", false];
		
		if(_isAlive && !_isMedic && !_isPlayer && _damage >= Auto_Medic_Incapacitation_Threshold && !_isIncapacitated) then {
			[_x] spawn {				    
				params  ["_injured"]; 
				_injured disableAI "MOVE";
				_injured setUnitPos "DOWN";		
				sleep 180;
				//Bleed Out...
				if(_damage >= Auto_Medic_Incapacitation_Threshold) then { _injured setDammage 1  };
			};
		};		
	} forEach units group player; 
};

Auto_Medic_GetMostInjured = {
	if(!Auto_Medic_Running) exitWith {}; 
	_injured = objNull; 
	_mostDamage = 0;
	{
		if (alive _x && !(_x getVariable ["HealingSelf", false]) && !(_x getVariable ["BeingHealed", false])) then {
			_damage = getDammage _x; 
			//Get Most Injured
			if ((_damage >= Auto_Medic_Damage_Threshold) && (_damage > _mostDamage)) then {				
				_injured = _x;
				_mostDamage = _damage;
			};
		};
	} forEach units group player;
	_injured;
}; 

Auto_Medic_Heal = {
	params  ["_injured"];
	if(!Auto_Medic_Running) exitWith {};
		
	_isPlayer = isPlayer _injured;
	_isAlive = alive _injured;
	_isMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _injured >> "attendant" ) isEqualTo 1;	        
    _hasFirstAid = 	"FirstAidKit" in (items _injured);
	_isIncapacitate = _injured getVariable ["Incapacitated", false];
	
	if(!_isAlive) exitWith{};		

	if(_isMedic) exitWith {
		[_injured] spawn Auto_Medic_HealSelf;
	};
	
	if(_isPlayer || !_hasFirstAid || _isIncapacitate) exitWith { 		
		[_injured] spawn Auto_Medic_HealInjured;		
	}; 
	 
	[_injured] spawn Auto_Medic_HealSelf;
};

Auto_Medic_HealSelf = { 
	params  ["_injured"];	
 	if(!Auto_Medic_Running) exitWith {};
	
	_injured disableAI "MOVE";
	_injured setUnitPos "DOWN";		
	_injured setVariable ["HealingSelf", true];
	_injured removeItem "FirstAidKit";
	_injured action ["HealSoldierSelf", _injured]; 			
	sleep 5;
	_injured setDamage 0;
	_injured setVariable ["HealingSelf", false]; 
	_injured enableAI "MOVE";
	_injured setUnitPos "auto";	
}; 

Auto_Medic_HealInjured = { 
	params  ["_injured"];
	_medic = [] call Auto_Medic_GetMedic;
	if(isNull _medic) exitWith {};
	
	if(!Auto_Medic_Running) exitWith {};

	if ((_medic getVariable ["Healing", false]) || (_medic getVariable ["HealingSelf", false])) exitWith {};
	if (getDammage _medic >= Auto_Medic_Damage_Threshold) exitWith { [_medic] spawn Auto_Medic_HealSelf; };
	
    _injured setVariable ["BeingHealed", true];
	_medic setVariable ["Healing", true];
	
	_injured disableAI "MOVE";
	_injured setUnitPos "DOWN";		
	
	if (Auto_Medic_Need_Radio) then {_injured groupChat format["MEDIC!"]}; 
	sleep 1;
	if (Auto_Medic_Need_Radio) then {_medic groupChat format["MOVING! Hold tight %1.", (name _injured)];}; 
	
	[_medic, _injured] call Auto_Medic_MoveMedicToInjured;
 
 	while {(_medic distance _injured > 3) && (alive _injured) && (!isNull _injured)} do {		
		if (getDammage _medic >= Auto_Medic_Damage_Threshold) exitWith { [_medic] spawn Auto_Medic_HealSelf; }; 
		sleep 1;
	};   
 
    if (!(alive _medic) || !(alive _injured)) exitWith {};

	_medic setDir ([_medic, _injured] call BIS_fnc_relativeDirTo);
	
	_medic action ["HealSoldierSelf", _injured]; 			
	sleep 5;
	_injured setDamage 0;

	if(isPlayer _injured) then {		
	    sleep 1;
		_injured setUnconscious false;
		[ "#rev", 1, _injured ] call BIS_fnc_reviveOnState;	
		sleep 2;
	};
	
	_injured enableAI "MOVE";
	_injured setUnitPos "auto";
	
	if(isPlayer _injured) then {
		_injured setUnconscious false;
		[ "#rev", 1, _injured ] call BIS_fnc_reviveOnState;	
	}

	_medic enableAI "MOVE";
	_medic setUnitPos "auto";
	//doMove stops the medic, so we have to command him to follow his leader
	_medic doFollow (leader group _medic);
 
	_injured setVariable ["BeingHealed", false];
	_injured setVariable["Incapacitated", false];
	_medic setVariable ["Healing", false];
}; 
 
Auto_Medic_MoveMedicToInjured = { 
	params  ["_medic", "_injured"];
	if(!Auto_Medic_Running) exitWith {};
	
	if(getDammage _medic >= Auto_Medic_Damage_Threshold) exitWith {
		_medic setVariable ["Healing", false];
		[_medic] spawn Auto_Medic_HealSelf; 
	};
	_medic doMove (position _injured);  
};  
 
Auto_Medic_ResetUnitVariables = {
	{
		_x setVariable ["BeingHealed", false];
		_x setVariable["Incapacitated", false];
		_isMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _x >> "attendant" ) isEqualTo 1;
		if(_isMedic) then {
			_x setVariable ["Healing", false];	
		};
		_x enableAI "MOVE";
		_x setUnitPos "auto";
	} forEach units group player;
};
 
 
waitUntil { alive player && !(isNull ([] call Auto_Medic_GetMedic))};
[] call Auto_Medic_Init; 