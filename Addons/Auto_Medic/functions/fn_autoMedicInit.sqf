Auto_Medic_Running = false;
Auto_Medic_Damage_Threshold = .3;
Auto_Medic_Incapacitation_Threshold = .8;
Auto_Medic_Need_Radio = true; 

Auto_Medic_Init = {	
    player addEventHandler ["killed", {[] spawn Auto_Medic_Reset}];
	[] call Auto_Medic_Start; 
};
 
Auto_Medic_Start = {	
    Auto_Medic_Running = true; 	
	[] call Auto_Medic_Start_Monitors; 
};

Auto_Medic_Stop = {
    Auto_Medic_Running = false;
	if !(isNil "Auto_Medic_Action_On") then { (player) removeAction Auto_Medic_Action_On; };
	if !(isNil "Auto_Medic_Action_Off") then { (player) removeAction Auto_Medic_Action_Off; };
    [] call Auto_Medic_Add_Action_On;
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
		_isIncapacitated = _x getVariable["AM_Incapacitated", false];
		
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
		_isWaitingToBeHealed = _x getVariable ["AM_WaitingToBeHealed", false]; 
		if (alive _x && _isWaitingToBeHealed) then {
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
 

Auto_Medic_HealSelf = { 
	params  ["_injured"];	
 	if(!Auto_Medic_Running) exitWith {};
	
	_injured disableAI "MOVE";
	_injured setUnitPos "DOWN";		
	_injured setVariable ["AM_HealingSelf", true];
	_injured removeItem "FirstAidKit";
	_injured action ["HealSoldierSelf", _injured]; 			
	sleep 5;
	_injured setDamage 0;
	_injured setVariable ["AM_HealingSelf", false]; 
	_injured enableAI "MOVE";
	_injured setUnitPos "auto";	
}; 

Auto_Medic_HealInjured = { 
	params  ["_medic", "_injured"];
	
	if(isNull _medic) exitWith {};
	
	if(!Auto_Medic_Running) exitWith {};

	if ((_medic getVariable ["AM_Healing", false]) || (_medic getVariable ["AM_HealingSelf", false])) exitWith {};
	if (getDammage _medic >= Auto_Medic_Damage_Threshold) exitWith { [_medic] spawn Auto_Medic_HealSelf; };
	
	_injured setVariable ["AM_WaitingToBeHealed", false];
    _injured setVariable ["AM_BeingHealed", true];
	_medic setVariable ["AM_Healing", true];
	
	_injured disableAI "MOVE";
	_injured setUnitPos "DOWN";		
	 
	sleep 1;
	if (Auto_Medic_Need_Radio) then {_medic groupChat format["MOVING! Hold tight %1.", (name _injured)];}; 
	
	
 
 	while {(_medic distance _injured > 3) && (alive _injured) && (!isNull _injured)} do {
		[_medic, _injured] call Auto_Medic_MoveMedicToInjured;		
		sleep 2;
	};   
	
	_medic setVariable ["AM_MovingToHeal", false];
	
    if (!(alive _medic) || !(alive _injured)) exitWith {
		if(!alive _injured) then {
				_medic enableAI "MOVE";
				_medic setUnitPos "auto";
				_medic setVariable ["AM_Healing", false];
				_medic doFollow (leader group _medic);				
				if (Auto_Medic_Need_Radio) then {_medic groupChat format["We lost %1.", (name _injured)];}; 				
		};
	};

	_medic setDir ([_medic, _injured] call BIS_fnc_relativeDirTo);
	
	_medic action ["HealSoldierSelf", _injured]; 			
	sleep 5;
	_injured setDamage 0;

	if(isPlayer _injured) then {
		_injured setUnconscious false;
		[ "#rev", 1, _injured ] call BIS_fnc_reviveOnState;	
	};
	
	_injured enableAI "MOVE";
	_injured setUnitPos "auto";
	 
	_medic enableAI "MOVE";
	_medic setUnitPos "auto";
	
	//doMove stops the medic, so we have to command him to follow his leader
	_medic doFollow (leader group _medic);
 
	_injured setVariable ["AM_BeingHealed", false];
	_injured setVariable["AM_Incapacitated", false];
	_medic setVariable ["AM_Healing", false];
}; 
 
Auto_Medic_MoveMedicToInjured = { 
	params  ["_medic", "_injured"];
	if(!Auto_Medic_Running) exitWith {};
	_isHealingSelf = _medic getVariable ["AM_HealingSelf", false];	
	if(_isHealingSelf) exitWith {};	
	_medic setVariable ["AM_MovingToHeal", true];
	_medic doMove (position _injured);  
};  
 
Auto_Medic_ResetUnitVariables = {
	{
		_x setVariable ["AM_BeingHealed", false];
		_x setVariable["AM_Incapacitated", false];
		_isMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _x >> "attendant" ) isEqualTo 1;
		if(_isMedic) then {
			_x setVariable ["AM_Healing", false];	
		};
		_x enableAI "MOVE";
		_x setUnitPos "auto";
	} forEach units group player;
};

Auto_Medic_Start_Monitors = { 
    [] spawn Auto_Medic_GroupMonitor;
};

Auto_Medic_Reset = {
	waitUntil { alive player };
	if(Auto_Medic_Running) then {
		[] spawn Auto_Medic_Stop;
		sleep 4;
		[] spawn Auto_Medic_Start;
	}
	else {
		[] spawn Auto_Medic_Start;
		sleep 4;
		[] spawn Auto_Medic_Stop;		
	};
};

Auto_Medic_CallForMedic = {
	params  ["_injured"];
	_injured setVariable ["AM_WaitingToBeHealed", true];
 
	if (Auto_Medic_Need_Radio) then {_injured groupChat format["MEDIC!"]}; 	 
};


Auto_Medic_GroupMonitor = {
	while {Auto_Medic_Running} do {
		{
			_beingMonitored = _x getVariable ["AM_BeingMonitored", false];
			if(_beingMonitored) exitWith {};
			
			_x setVariable ["AM_BeingMonitored", true];
			_x setVariable ["AM_BeingHealed", false];
			_x setVariable ["AM_Incapacitated", false];
			_isMedic = getNumber ( configFile >> "CfgVehicles" >> typeOf _x >> "attendant" ) isEqualTo 1;
			_isPlayer = isPlayer _x;			
		
			if(_isMedic) then {
				_x setVariable ["AM_Healing", false];	
				[_x] spawn Auto_Medic_MedicMonitor;
			};
			if(_isPlayer) then {
				[] spawn Auto_Medic_PlayerMonitor;
			};	
			if(!_isPlayer && !_isMedic) then {
				[_x] spawn Auto_Medic_AIMonitor;
			};	
		} forEach units group player;
		sleep 3;
	};
}; 

Auto_Medic_PlayerMonitor = { 	  
 	_waitTime = 0;
	while {alive player && Auto_Medic_Running} do {	 
		if (isNil "Auto_Medic_Action_Off") then { [] call Auto_Medic_Add_Action_Off };   
		_isWaitingToBeHealed = player getVariable ["AM_WaitingToBeHealed", false]; 
		_isHealingSelf = player getVariable ["AM_HealingSelf", false];
		_isBeingHealed = player getVariable ["AM_BeingHealed", false];		
		_isInjured = (getDammage player) >= Auto_Medic_Damage_Threshold; 
 		
		if(!_isInjured || _isHealingSelf || _isBeingHealed) exitWith {
			sleep 2;
			[] spawn Auto_Medic_PlayerMonitor;
		};		
		
		if(_isWaitingToBeHealed) then {
			//Have waited 24 seconds, lets try again...
			if(_waitTime > 0 && _waitTime mod 24 == 0) then {
				[player] call Auto_Medic_CallForMedic;
			}; 
			_waitTime = _waitTime + 2;					
		}
		else { 
			[player] call Auto_Medic_CallForMedic; 		
		};

			
		sleep 2;		
	}
}; 
Auto_Medic_AIMonitor = { 	
	params  ["_ai"]; 
	_waitTime = 0;
	while {alive _ai && Auto_Medic_Running} do {		
		_isWaitingToBeHealed = _ai getVariable ["AM_WaitingToBeHealed", false]; 
		_isHealingSelf = _ai getVariable ["AM_HealingSelf", false];
		_isBeingHealed = _ai getVariable ["AM_BeingHealed", false];		
		_isInjured = (getDammage _ai) >= Auto_Medic_Damage_Threshold; 
		
		if(!_isInjured || _isHealingSelf || _isBeingHealed) exitWith {
			sleep 2;
			[_ai] spawn Auto_Medic_AIMonitor;
		};		

		if(_isWaitingToBeHealed) then {
			//Have waited 24 seconds, lets try again...
			if(_waitTime > 0 && _waitTime mod 24 == 0) then {
				[_ai] call Auto_Medic_CallForMedic;
			}; 
			_waitTime = _waitTime + 2;					
		}
		else {
			_hasFirstAid = 	"FirstAidKit" in (items _ai);
			_isIncapacitate = _ai getVariable ["AM_Incapacitated", false];
			if(_hasFirstAid && !_isIncapacitate) then {
				[_ai] spawn Auto_Medic_HealSelf;
			}
			else {
				[_ai] call Auto_Medic_CallForMedic;
			};				
		};
			
		sleep 2;
	};  
}; 
Auto_Medic_MedicMonitor = {  
	params  ["_medic"];  
 
	while {alive _medic && Auto_Medic_Running} do {
		_isHealing = _medic getVariable ["AM_Healing", false];
		_isMovingToHeal = _medic getVariable ["AM_MovingToHeal", false];		
		_isHealingSelf = _medic getVariable ["AM_HealingSelf", false];	
		_isInjured = (getDammage _medic) >= Auto_Medic_Damage_Threshold; 

		//Heal Self before anything else
		if (!_isHealingSelf && _isInjured) then {
			[_medic] spawn Auto_Medic_HealSelf; 
		};
		
		//If busy, restart loop
		if(_isMovingToHeal || _isHealing || _isHealingSelf) exitWith {
			sleep 2;
			[_medic] spawn Auto_Medic_MedicMonitor 
		};
		
		//Heal others
		if (!_isHealing && !_isHealingSelf && !_isInjured) then { 
			_injured = [] call Auto_Medic_GetMostInjured; 			 			 
			//[] spawn Auto_Medic_IncapacitateAiUnits;
			
			if (!isNull _injured) then {				
				[_medic, _injured] spawn Auto_Medic_HealInjured; 
			}			
		};	
		sleep 2; 
	}; 
}; 
 
 
Auto_Medic_Add_Action_On = {
	Auto_Medic_Action_On = (player) addAction ["Auto-Medic ON", "[] spawn Auto_Medic_Start; ", [true], 1, false, true, "", "true"]; 
};

Auto_Medic_Add_Action_Off = {
	Auto_Medic_Action_Off = (player) addAction ["Auto-Medic OFF", "[] spawn Auto_Medic_Stop; ", [], 1, false, true, "", "true"];
};
 
waitUntil { alive player && (count units group player > 1)};
[] call Auto_Medic_Init; 
