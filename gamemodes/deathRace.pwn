/*

By Seregamil


adminCMD's:
	kick
	ban
	
Таймеры
Отсчеты
Запрет на вылазку из корыта
Уничтожение машины
Полная система регистрации, логина, сохранения, детекта мультиаккаунтов по IP

Выбор машины, улучшения, запуск раунда, ТД с временем
Гидравлика
Объекты ракет для атача
Стрельба из ракеты
Немного оптимизации, перевод ID машин в массив и выбор из него, а не через кейсы, перестроен общий таймер
Немного чар.

Система пикапов
Запуск зон из массива по ID

3 зоны
		
Убраны переменные и таймеры на ракеты.
Убраны переменные на пользователей.
Оптимизировали кароче.

Переделана система стрельбы
Исправлены баги со стрельбой
Первый тест не прошел крахом.

Текстдравы
Шкала с процентами
Профикшен баг со спавном игрока после окончания раунда
ХР машины синхронизировано с ХР игроков

Таймер и камера перед запуском режима
Исправлена пара багов
Актуальными багами остаются спавн после смерти игрока

Исправлены баги связанные со смертю и спавнами игроков.

Вроде зафикшены баги с камерой.
Добавлен каллбэк OnRocketTakeDamage(owner_vehicle, vehicleid) - срабатывает при попадании ракеты в машину
Добавлен каллбэк OnUserDeath(playerid) - срабатывает при смерти игрока в раунде

Добавлена дисквалификация игрока из раунда из-за АФК.
Добавлен каллбэк OnPlayerShotRocket(playerid) - срабатывает при выстреле ракетой
Озвучка из тактикса
Убран один таймер и переведен в OnPlayerUpdate, с ним веселее
Созданы перки
Создана панель для перков
Все перки активны.
Rock'nRoll (:
Профикшена пара косяков
В общем конфетка

Добавлен каллбэк OnPlayerUsedModification(playerid, modification_id) - срабатывает при использовании модификации
Добавлен массив с названиями модификаций
Отключена возможность попасть в самого себя
У каждой ракеты теперь есть свой владелец
ХР машины синхронизировано с ХР персонажа

Подключен аудио плагин
Профикшен один баг с положением камеры при старте раунда
Изменено обновление TextDrawов
Изменил таймер всеобщий, убрал время для запуска арены, пусть по кнопочке голосуют
Добавлена система голосования со всеми причендалами
Исправлено 2 бага
Профикшен косяк с текстом в голосовании
Добавлено ХР игроков
Сделал голосование человеческое.

Система бензина(без заправки, есть проблема с ТД(при обновлении))
Исправлена проблема с пикапами
Изменен бар для топлива.
Система топлива активирована и работоспособна.
*/

#include a_samp
#include mxINI
#include matrix
#include audio

#define dcmd(%1,%2,%3) if((strcmp((%3)[1],#%1,true,(%2))==0)&&((((%3)[(%2)+1]==0)&&(dcmd_%1(playerid,"")))||(((%3)[(%2)+1]==32)&&(dcmd_%1(playerid,(%3)[(%2)+2]))))) return 1
#define IsPlayerInAFK(%0) ((GetTickCount() - _afk[%0]) >= 3000)

native IsValidVehicle(vehicleid);

#define MINIMAL_USERS 1

#undef MAX_PLAYERS
#undef MAX_VEHICLES

#define MAX_PLAYERS 10
#define MAX_VEHICLES (MAX_PLAYERS + 1)

#undef MAX_PICKUPS
#define MAX_PICKUPS 100

#define pathDB "server.db"

#define version "0.2.0"

#define p_name(%0) _name[%0]
#define p_ip(%0) _ip[%0]

#define ROUND_VEHICLE_HEALTH 15000.0
#define ROCKET_SPEED 100.0
#define EXPLOSION_RADIUS 40.0

#define ROUND_MINUTES 7
#define ROUND_SECONDS 0

#define SECONDS_TIME 10
#define MINUTES_TIME 0

#define REGISTER_TEXT "{ffffff}Привет!\nДля начала игры советую зарегистрироваться.\nРазрешенные символы: A-Z, a-z, 0-9."

forward updMode();//таймер для обновления мода
forward previewMode(area_id);//камера и отсчет
forward OnUserDeath(playerid);//смерть игрока в раунде
forward OnPlayerUsedModification(playerid, modification_id);//использование модификации
forward OnPlayerShotRocket(playerid);//выстрел ракетой
forward _rocketUpdate(objectid);//обновление для ракеты
forward OnRocketTakeDamage(playerid, owner_vehicle, vehicleid);//нанесение урона

new round;

new Text: Textdraw0;
new Text: ProgressBar[5];
new Text: modeVersion;
new Text: voteDraw[2];

new PlayerText:Procent[MAX_PLAYERS];
new PlayerText:rocketReload[MAX_PLAYERS];

new PlayerText:fuelDraw[MAX_PLAYERS];
new PlayerText:rangDraw[MAX_PLAYERS];

new PlayerText:modificationProcent[MAX_PLAYERS];
new PlayerText:modificationReload[MAX_PLAYERS];

new PlayerText:healthDraw[MAX_PLAYERS];

//new _timer[MAX_PLAYERS];

new _name[MAX_PLAYERS][MAX_PLAYER_NAME + 1];
new _ip[MAX_PLAYERS][16];
new _carObjects[MAX_VEHICLES][2];

new j_count[MAX_PLAYERS];
new Float: modificationTime[MAX_PLAYERS];
new _afk[MAX_PLAYERS];

new bool: vote_active = false;
new vote_time = 0;

new bool: p_spawned[MAX_PLAYERS char];
new total_shots[MAX_PLAYERS];
//new round_shots[MAX_PLAYERS];

new bool: roundEnabled = false;
new _min = 0, _sec = 10;

new File: s_hMap;
new _pickup[MAX_PICKUPS];
new _objectOwn[MAX_OBJECTS];

new Float:fuelCar[MAX_VEHICLES];

//new voteStr[256];

new DB: _db;
new DBResult: _db_result;
new protect = 0;
new preview = 0;
new a_info[3];

new modification_name[][24] = {
	"Fast rocket",
	"Hydraulics",
	"Quick Reload"
};

new vehicles[10] = {
	602, 429, 496, 402, 541, 415, 451, 603, 506, 477
};

main(){
	new totalPlayers = GetServerVarAsInt("maxplayers");
	if(totalPlayers != MAX_PLAYERS){
	    printf("Error: %i != %i", totalPlayers, MAX_PLAYERS);
	    SendRconCommand("exit");
	}
	
	if(!fexist("banned/")){
		print("Error: directory 'banned' is not exist");
	    SendRconCommand("exit");
	}
	
	if(!fexist("SAfull.hmap")){
		print("Error: SAfull.hmap is not exist");
	    SendRconCommand("exit");
	}
	
    s_hMap = fopen("SAfull.hmap", io_read);
    
    if(!s_hMap) {
		print("SAfull.hmap: error.");
	    SendRconCommand("exit");
	}
}

new Float:_createPickups[86][4] = {
	{2536.3610840,-1709.6610107,13.4139996}, //(1)
	{2445.9729004,-1976.9890137,13.5240002}, //(2)
	{2297.7189941,-2022.0219727,12.7679996}, //(3)
	{2082.1469727,-2041.5159912,12.7740002}, //(4)
	{1867.1770020,-2007.9129639,12.7740002}, //(5)
	{1964.0290527,-2216.7460938,15.3520002}, //(6)
	{2200.9079590,-2301.3520508,13.9919996}, //(7)
	{2787.4130859,-2487.0520020,12.8780003}, //(8)
	{1392.6700439,-1486.5100098,7.8990002}, //(9)
	{1428.9100342,-1085.9040527,16.7889996}, //(10)
	{1678.3050537,-1204.2750244,19.0820007}, //(11)
	{1786.2879639,-1230.7440186,16.1459999}, //(12)
	{1967.8890381,-1177.4169922,19.2579994}, //(13)
	{2090.8000488,-1081.3590088,24.7579994}, //(14)
	{2379.7709961,-1033.4439697,53.1040001}, //(15)
	{2493.2529297,-952.1279907,81.4729996}, //(16)
	{2762.7509766,-669.7800293,63.8639984}, //(17)
	{2548.8759766,-13.6689997,25.8910007}, //(18)
	{2280.8369141,-50.4029999,26.2530003}, //(19)
	{2153.2290039,-92.5279999,1.9180000}, //(20)
	{1903.3039551,142.4900055,34.6090012}, //(21)
	{1555.4949951,257.2229919,14.8339996}, //(22)
	{1431.1290283,228.5039978,18.7819996}, //(23)
	{1197.9870605,253.0209961,18.7819996}, //(24)
	{985.2919922,161.1629944,27.7180004}, //(25)
	{357.3779907,-79.8290024,0.5920000}, //(26)
	{251.8999939,-157.4140015,0.7980000}, //(27)
	{96.4899979,-165.0030060,1.8210000}, //(28)
	{-20.6520004,-225.0899963,4.6570001}, //(29)
	{-84.2620010,-102.5739975,2.3450000}, //(30)
	{-421.7170105,179.7640076,4.2249999}, //(31)
	{-671.9349976,215.7550049,1.9990000}, //(32)
	{-480.1069946,-197.9140015,77.5120010}, //(33)
	{-397.6809998,-428.6870117,15.4300003}, //(34)
	{-557.6090088,-505.9219971,23.7859993}, //(35)
	{-97.0719986,-1020.0650024,13.7510004}, //(36)
	{-803.6320190,-941.8449707,103.5630035}, //(37)
	{-1098.1259766,-1006.1580200,128.4459991}, //(38)
	{-1362.5150146,-496.4190063,13.3990002}, //(39)
	{-1383.7550049,-399.0459900,5.2270002}, //(40)
	{-1728.7239990,-364.4169922,16.3680000}, //(41)
	{-1538.6049805,134.5850067,2.7820001}, //(42)
	{-1640.7440186,99.0790024,-11.9189997}, //(43)
	{-1848.6109619,-128.7149963,11.1260004}, //(44)
	{-2197.2580566,-224.8650055,34.5480003}, //(45)
	{-2146.6450195,-91.3369980,40.8240013}, //(46)
	{-2316.9589844,-23.3789997,34.5480003}, //(47)
	{-2485.7600098,116.4769974,31.3600006}, //(48)
	{-2535.6269531,53.1440010,7.8449998}, //(49)
	{-2654.0119629,85.7939987,3.2739999}, //(50)
	{-2763.0371094,84.9980011,6.1320000}, //(51)
	{-2796.5839844,235.0820007,6.4150000}, //(52)
	{-2947.7749023,504.4200134,1.6569999}, //(53)
	{-2818.7219238,1126.1639404,25.9650002}, //(54)
	{-2685.7690430,1429.9410400,6.3210001}, //(55)
	{-1993.1090088,1384.3800049,6.4120002}, //(56)
	{-1631.3950195,653.2999878,-6.0149999}, //(57)
	{-1332.3900146,437.3420105,6.4080000}, //(58)
	{-1680.0529785,421.5469971,6.4070001}, //(59)
	{-1416.2969971,648.7150269,33.8050003}, //(60)
	{-885.7299805,1008.1510010,20.4150009}, //(61)
	{-749.3499756,1132.2509766,31.7539997}, //(62)
	{-794.8010254,1435.4730225,13.0159998}, //(63)
	{-1067.1350098,2199.0358887,86.9970016}, //(64)
	{-1472.2080078,2626.1599121,55.0629997}, //(65)
	{-1596.4510498,2695.6459961,54.2830009}, //(66)
	{-793.2139893,2772.5681152,44.9300003}, //(67)
	{-630.5040283,2690.6520996,71.6019974}, //(68)
	{-268.9750061,2662.2890625,65.2229996}, //(69)
	{189.8520050,2632.6918945,15.7049999}, //(70)
	{709.8189697,2347.0319824,16.2169991}, //(71)
	{1019.7509766,2166.9030762,10.0480003}, //(72)
	{1602.9830322,1478.3649902,10.0550003}, //(73)
	{2188.5820312,1463.1070557,10.0480003}, //(74)
	{2386.9689941,1016.1500244,10.0480003}, //(75)
	{2855.1879883,892.0670166,9.0380001}, //(76)
	{2868.2209473,1012.4359741,9.9770002}, //(77)
	{2827.2490234,1245.5050049,9.9960003}, //(78)
	{2327.5139160,1521.1600342,43.9389992}, //(79)
	{2123.7490234,1146.1330566,12.7360001}, //(80)
	{2107.5710449,1003.8950195,10.2989998}, //(81)
	{1652.6770020,1293.5510254,10.0550003}, //(82)
	{1126.9110107,704.5839844,9.6859999}, //(83)
	{1650.9720459,606.6959839,7.0089998}, //(84)
	{2391.9699707,548.0529785,7.0089998}, //(85)
	{2767.1809082,512.3209839,7.5170002} //(86)
};

new Float: _zones[30][5] = {
	//golf
	{1127.6936,2742.8157,10.5478,315.0324},
	{1125.7952,2820.1807,10.5459,301.8072},

	{1143.1354,2849.3799,10.5464,246.5114},
	{1204.9465,2857.6592,10.5473,162.3648},

	{1279.7035,2823.8557,10.5469,94.4333},
	{1328.7382,2753.0256,10.5453,42.6806},

	{1384.9922,2830.8003,10.5471,126.1139},
	{1371.6460,2745.2046,10.5468,68.9719},

	{1279.0376,2729.1370,10.5435,71.3498},
	{1204.0238,2760.3320,10.5518,20.9407},
	//desert airport
	{418.1781,2622.9470,50.6874,142.9493},
	{304.8831,2585.1492,16.1056,171.3204},

	{242.6720,2550.5847,16.3479,221.0161},
	{178.4192,2526.4775,16.4013,245.9165},

	{185.3296,2409.4209,16.0931,36.5938},
	{268.7349,2454.4175,16.0948,12.4217},

	{360.4158,2460.5693,16.0945,17.2770},
	{404.3900,2452.2366,16.1066,357.9444},

	{466.3833,2494.0620,22.5703,56.2402},
	{72.5781,2464.6943,16.0866,292.8224},
	//LV airport
	{1283.7747,1315.7723,10.5900,301.4789},
	{1283.1492,1356.1163,10.5904,309.5636},

	{1323.6598,1536.8240,14.6467,270.2301},
	{1346.5543,1671.0173,10.5917,252.8050},

	{1397.9921,1772.7928,10.5935,236.4722},
	{1563.3505,1683.9368,10.5910,43.8807},

	{1589.2781,1527.0671,10.6007,34.1281},
	{1709.9862,1324.9285,10.5635,100.5295},

	{1486.0546,1175.0458,13.4250,1.6115},
	{1312.6532,1211.8347,10.5911,309.1499}
};

new Float: _fuelZone[10][4] = {
	{1597.4139404,2198.8710938,11.3699999},//(2)
	{2114.7141113,920.0490112,11.3699999},//(3)
	{70.4690018,1218.2380371,19.1119995},//(4)
	{-1471.2030029,1863.5369873,32.9319992},//(5)
	{-2415.1289062,977.1010132,45.8460007},//(6)
	{-1679.0479736,410.6679993,7.9790001},//(7)
	{-2029.8940430,156.4060059,29.1350002},//(8)
	{-91.8059998,-1170.5849609,2.7019999},//(9)
	{1004.9840088,-933.1220093,42.9790001},//(10)
	{1937.8879395,-1772.2290039,14.4320002}//(11)
};

#define MAX_STANTIONS (sizeof _fuelZone)

new Text3D: _fuelText[MAX_STANTIONS];
new Float: _stantionFuel[MAX_STANTIONS];
new _fuelPickup[MAX_STANTIONS];

new a_name[][30] = {
	"Golf club",
	"Desert airport",
	"Las Venturas airport"
};

public OnGameModeInit(){

	UsePlayerPedAnims();
	
	new j = -1;
	while(++j != 300) AddPlayerClass(j, 2244.2566,2523.7280,10.8203, 102.3370, 0,0,0,0,0,0);

    clearObjects();

	for(j = 0; j != sizeof a_info; j++) a_info[j] = 0;
	//voteStr = " ";
    vote_active = false;
	vote_time = 0;

	_db = db_open(pathDB);
	db_query(_db, "CREATE TABLE IF NOT EXISTS ACCOUNTS(USERNAME varchar, IP varchar, PASSWORD varchar, MONEY varchar, SHOTS int)");

	_db_result = db_query(_db, "SELECT * FROM ACCOUNTS");
	printf("Registered: %i users", db_num_rows(_db_result));
	db_free_result(_db_result);

	createTextDraws();
	vote_time = 0;
	SendRconCommand("hostname !Lagsters");
	SetGameModeText("!Lagsters v"version"");
	roundEnabled = false;
	Audio_SetPack("default_pack");
	SetTimer("updMode", 1000, true);
	//SetTimer("uMode", 70, true);
	return 1;
}

/*forward uMode();
public uMode(){
	new playerid = -1;
	while(++playerid!=MAX_PLAYERS){
	    if(!IsPlayerConnected(playerid)) continue;
	    if(IsPlayerNPC(playerid)) continue;
	    if(!p_spawned{playerid}) continue;
	    if(IsPlayerInAFK(playerid)) continue;
		new vehicleid = GetPlayerVehicleID(playerid);
		if(roundEnabled && GetPVarInt(playerid, "_inRound") && IsPlayerInAnyVehicle(playerid) && vehicleid == GetPVarInt(playerid, "_veh")){

			new engine,lights,alarm,doors,bonnet,boot,objective;
			GetVehicleParamsEx(vehicleid,engine,lights,alarm,doors,bonnet,boot,objective);
			if(engine){
				fuelCar[vehicleid] -= 0.020;

				PlayerTextDrawDestroy(playerid, fuelDraw[playerid]);

				fuelDraw[playerid] = CreatePlayerTextDraw(playerid, 549.764221 + (fuelCar[vehicleid] * 0.58503502), 58.666667, "usebox");
				PlayerTextDrawLetterSize(playerid, fuelDraw[playerid], 0.000000, 0.066837);
				PlayerTextDrawTextSize(playerid, fuelDraw[playerid], 546.170043, 0.000000);
				PlayerTextDrawAlignment(playerid, fuelDraw[playerid], 1);
				PlayerTextDrawColor(playerid, fuelDraw[playerid], 0);
				PlayerTextDrawUseBox(playerid, fuelDraw[playerid], true);
				PlayerTextDrawBoxColor(playerid, fuelDraw[playerid], -2003304193);
				PlayerTextDrawSetShadow(playerid, fuelDraw[playerid], 0);
				PlayerTextDrawSetOutline(playerid, fuelDraw[playerid], 0);
				PlayerTextDrawFont(playerid, fuelDraw[playerid], 0);

				PlayerTextDrawShow(playerid, fuelDraw[playerid]);

				if(fuelCar[vehicleid] <= 0.0){
				    SetVehicleParamsEx(vehicleid,0,0,alarm,doors,bonnet,boot,objective);
				    SendClientMessage(playerid, -1, "Двигатель заглох, я тебя поздравляю.");
				}
			}
			new Float:health;
			GetVehicleHealth(vehicleid, health);
			if(health > 200.0) SetPlayerHealth(playerid, floatround(health / 150.0));

			new str[27];
			format(str, sizeof str, "%i", floatround(health / 150.0));
			PlayerTextDrawSetString(playerid,  healthDraw[playerid], str);
			PlayerTextDrawShow(playerid, healthDraw[playerid]);

			if(j_count[playerid] != 100){
			    j_count[playerid] += 2;

			    PlayerTextDrawDestroy(playerid, rocketReload[playerid]);

				rocketReload[playerid] = CreatePlayerTextDraw(playerid, 495.500000 + (float(j_count[playerid]) * 1.13375), 81.999992, "_");
				PlayerTextDrawLetterSize(playerid, rocketReload[playerid], 0.000000, 1.384720);
				PlayerTextDrawTextSize(playerid, rocketReload[playerid], 495.500000, 0.000000);
				PlayerTextDrawAlignment(playerid, rocketReload[playerid], 1);
				PlayerTextDrawUseBox(playerid, rocketReload[playerid], true);
				PlayerTextDrawBoxColor(playerid, rocketReload[playerid], 0xff8800FF);

				PlayerTextDrawShow(playerid, rocketReload[playerid]);

				//new str[27];
				format(str,sizeof str,"Simple rocket: %i%", j_count[playerid]);
				PlayerTextDrawSetString(playerid, Procent[playerid], str);
			}
			if(modificationTime[playerid] != 100){
			    modificationTime[playerid] += (GetPVarInt(playerid, "_mode") == 2 ? (2.5) : (0.5));

				PlayerTextDrawDestroy(playerid, modificationReload[playerid]);

				modificationReload[playerid] = CreatePlayerTextDraw(playerid, 495.500000 + (modificationTime[playerid] * 1.13375), 104.999992, "_");
				PlayerTextDrawLetterSize(playerid, modificationReload[playerid], 0.000000, 1.384720);
				PlayerTextDrawTextSize(playerid, modificationReload[playerid], 495.500000, 0.000000);
				PlayerTextDrawAlignment(playerid, modificationReload[playerid], 1);
				PlayerTextDrawUseBox(playerid, modificationReload[playerid], true);
				PlayerTextDrawBoxColor(playerid, modificationReload[playerid], 0x00960bff);

				PlayerTextDrawShow(playerid, modificationReload[playerid]);

				//new str[27];
			 	format(str,sizeof str,"%s: %i%", modification_name[GetPVarInt(playerid, "_mode")],floatround(modificationTime[playerid]));
				PlayerTextDrawSetString(playerid, modificationProcent[playerid], str);
			}
		}
		else{
		    PlayerTextDrawHide(playerid, healthDraw[playerid]);
		}
	}
}
*/
createTextDraws(){
    Textdraw0 = TextDrawCreate(317.600067, 32.853317, "05:16");
	TextDrawLetterSize(Textdraw0, 0.239599, 0.980266);
	TextDrawTextSize(Textdraw0, 1035.999633, -41.813331);
	TextDrawAlignment(Textdraw0, 2);
	TextDrawColor(Textdraw0, -1);
	TextDrawUseBox(Textdraw0, true);
	TextDrawBoxColor(Textdraw0, 76);
	TextDrawSetShadow(Textdraw0, 0);
	TextDrawSetOutline(Textdraw0, 1);
	TextDrawBackgroundColor(Textdraw0, 51);
	TextDrawFont(Textdraw0, 2);
	TextDrawSetProportional(Textdraw0, 1);
	
	ProgressBar[0] = TextDrawCreate(610.750000, 80.249961, "usebox");
	TextDrawLetterSize(ProgressBar[0], 0.000000, 1.787500);
	TextDrawTextSize(ProgressBar[0], 494.250000, 0.000000);
	TextDrawAlignment(ProgressBar[0], 1);
	TextDrawColor(ProgressBar[0], 0);
	TextDrawUseBox(ProgressBar[0], true);
	TextDrawBoxColor(ProgressBar[0], 255);
	TextDrawSetShadow(ProgressBar[0], 0);
	TextDrawSetOutline(ProgressBar[0], 0);
	TextDrawFont(ProgressBar[0], 0);

	ProgressBar[1] = TextDrawCreate(609.500000, 82.000015, "usebox");
	TextDrawLetterSize(ProgressBar[1], 0.000000, 1.449534);
	TextDrawTextSize(ProgressBar[1], 495.500000, 0.000000);
	TextDrawAlignment(ProgressBar[1], 1);
	TextDrawColor(ProgressBar[1], 0);
	TextDrawUseBox(ProgressBar[1], true);
	TextDrawBoxColor(ProgressBar[1], -5963592);
	TextDrawSetShadow(ProgressBar[1], 0);
	TextDrawSetOutline(ProgressBar[1], 0);
	TextDrawFont(ProgressBar[1], 0);
	
	ProgressBar[2] = TextDrawCreate(610.750000, 103.249961, "usebox");
	TextDrawLetterSize(ProgressBar[2], 0.000000, 1.787500);
	TextDrawTextSize(ProgressBar[2], 494.250000, 0.000000);
	TextDrawAlignment(ProgressBar[2], 1);
	TextDrawColor(ProgressBar[2], 0);
	TextDrawUseBox(ProgressBar[2], true);
	TextDrawBoxColor(ProgressBar[2], 255);
	TextDrawSetShadow(ProgressBar[2], 0);
	TextDrawSetOutline(ProgressBar[2], 0);
	TextDrawFont(ProgressBar[2], 0);

	ProgressBar[3] = TextDrawCreate(609.500000, 105.000015, "usebox");
	TextDrawLetterSize(ProgressBar[3], 0.000000, 1.449534);
	TextDrawTextSize(ProgressBar[3], 495.500000, 0.000000);
	TextDrawAlignment(ProgressBar[3], 1);
	TextDrawColor(ProgressBar[3], 0);
	TextDrawUseBox(ProgressBar[3], true);
	TextDrawBoxColor(ProgressBar[3], 0x297320FF);
	TextDrawSetShadow(ProgressBar[3], 0);
	TextDrawSetOutline(ProgressBar[3], 0);
	TextDrawFont(ProgressBar[1], 0);

	ProgressBar[4] = TextDrawCreate(609.672119, 56.916667, "usebox");
	TextDrawLetterSize(ProgressBar[4], 0.000000, 0.436111);
	TextDrawTextSize(ProgressBar[4], 544.295715, 0.000000);
	TextDrawAlignment(ProgressBar[4], 1);
	TextDrawColor(ProgressBar[4], 0);
	TextDrawUseBox(ProgressBar[4], true);
	TextDrawBoxColor(ProgressBar[4], 255);
	TextDrawSetShadow(ProgressBar[4], 0);
	TextDrawSetOutline(ProgressBar[4], 0);
	TextDrawFont(ProgressBar[4], 0);

	voteDraw[0] = TextDrawCreate(30.000000, 180.000000, " ");
    TextDrawFont(voteDraw[0], 1);
    TextDrawLetterSize(voteDraw[0], 0.20, 0.800000);
    TextDrawSetOutline(voteDraw[0], 1);
    TextDrawBoxColor(voteDraw[0], 0x00000070);
    TextDrawTextSize(voteDraw[0], 150, 400);
    TextDrawUseBox(voteDraw[0], 1);

    voteDraw[1] = TextDrawCreate(30.000000, 212.200000, " ");
    TextDrawFont(voteDraw[1], 1);
    TextDrawLetterSize(voteDraw[1], 0.20, 0.800000);
    TextDrawSetOutline(voteDraw[1], 1);
    TextDrawBoxColor(voteDraw[1], 0x00000070);
    TextDrawTextSize(voteDraw[1], 150, 400);
    TextDrawUseBox(voteDraw[1], 1);
    
	modeVersion = TextDrawCreate(638.500000, 438.666839, "!Lagsters v"version"");
	TextDrawLetterSize(modeVersion, 0.143500, 0.724999);
	TextDrawAlignment(modeVersion, 3);
	TextDrawColor(modeVersion, -1);
	TextDrawSetShadow(modeVersion, 0);
	TextDrawSetOutline(modeVersion, 1);
	TextDrawBackgroundColor(modeVersion, 51);
	TextDrawFont(modeVersion, 1);
	TextDrawSetProportional(modeVersion, 1);
}

public updMode(){
	if(preview == 0 && protect == 0){
		if(roundEnabled){
			new j = -1;

			while(++j != MAX_PLAYERS){
			    if((!IsPlayerConnected(j)) || (!GetPVarInt(j,"_inRound")) || (!IsPlayerInAFK(j))) continue;
				disqualification(j);
				SetPlayerPos(j, 2244.2566,2523.7280,10.8203);
				new str[128];
		    	format(str, sizeof str, "Игрок %s был дисквалифицирован за нахождение в АФК", p_name(j));
		    	SendClientMessageToAll(-1, str);
			}
			
			if( getAllUsersConnected() < MINIMAL_USERS || getAllUsersInRound() < MINIMAL_USERS ){
		        setWin();
				return;
			}
			
			_sec--;
			if(_sec <= 0){
				if(_min != 0){
					_min--;
					_sec = 59;
	    			switch(_min){
     					case 4: {
							j = -1;
							while(++j != MAX_PLAYERS){
								if((!IsPlayerConnected(j)) || (!GetPVarInt(j, "_inRound"))) continue;
								playAudio(j, 5);
							}
						}
		     			case 0: {
							j = -1;
							while(++j != MAX_PLAYERS){
			    				if((!IsPlayerConnected(j)) || (!GetPVarInt(j, "_inRound"))) continue;
								playAudio(j, 6);
							}
					    }
					}
				}
				else{
					setWin();
					return;
				}
			}
			new str[25];
			format(str, sizeof str, "%02d:%02d", _min, _sec);
			TextDrawSetString(Textdraw0, str);
			TextDrawShowForAll(Textdraw0);
		}
		else{//вне раунда
  			TextDrawHideForAll(Textdraw0);
  			if(getAllUsersConnected() < MINIMAL_USERS){
	            vote_active = false;
				vote_time = 0;
				new j = 0;
				for(j = 0; j!= MAX_PLAYERS; j++) SetPVarInt(j, "voted", 0);
				for(j = 0; j!= sizeof a_info; j++) a_info[j] = 0;
                TextDrawHideForAll(voteDraw[0]);
                TextDrawHideForAll(voteDraw[1]);
            }
            else{
	            if(vote_active){
					new str[250];
					format(str, sizeof str, "~y~Voting is started~n~~w~All ~p~players~w~ are to ~y~vote~n~~w~Press \"Y\" and choose areaid~n~~w~Time: ~w~(~r~%d~w~)", vote_time);
	                TextDrawSetString(voteDraw[0], str);
	                str = "";
					for(new i = 0; i!= sizeof a_info; i++) {
					    if(a_info[i] == 0) continue;
						format(str, sizeof str, "%s~w~%s ~y~(%i)~n~", str, a_name[i], a_info[i]);
					}
					TextDrawSetString(voteDraw[1], str);

					TextDrawShowForAll(voteDraw[0]);
	                TextDrawShowForAll(voteDraw[1]);
	                if(vote_time > 0) vote_time --;
	                else{
						/*new j = -1, leader = 0;
						while(++j != sizeof a_info){
						    if(a_info[j] > leader ) {
								leader = a_info[j];
								printf("leader: %i:%i", j, leader);
							}
						}*/
						preview = 3;
						previewMode(golos());
			            //setRound();
	                }
	            }
	            else{
	                TextDrawHideForAll(voteDraw[0]);
	                TextDrawHideForAll(voteDraw[1]);
	            }
            }
		}
	}
}

golos()
{
    new max_arena, return_arena[3], indx, id;

    for ( new i ; i != sizeof a_info ; ++ i )
	{
        if ( indx < a_info[i] )//если значение меньше чем у арены
        {
			max_arena = i;//поставим максимум значений на это арену
			indx = a_info[i];//номер будет равен этой арене
		}
	}
    for ( new i ; i != sizeof a_info ; ++ i )
    {
        if ( indx == a_info[i] )//если номер и арена совпали
        {
			return_arena[id++] = i ;//добавим к арене+1
		}
	}
    if(id) return return_arena[random(id)] ;//если кол-во голосов совпало - рандом
    return max_arena ;//запуск арены, у которой больше голосов
}

destroyPickups(){
	new j = -1;
	while(++j != MAX_PICKUPS){
	    DestroyPickup(j);
	}
}

destroy3DLabels(){
	new j = -1;
	while(++j != MAX_STANTIONS){
	    Delete3DTextLabel(_fuelText[j]);
	    _stantionFuel[j] = 0.0;
	}
}

public previewMode(area_id){
    new j = -1;

    protect = 1;
    vote_active = false;
	vote_time = 0;
	TextDrawHideForAll(voteDraw[0]);
 	TextDrawHideForAll(voteDraw[1]);
	if(preview == 0){
		while(++j != MAX_PLAYERS){
		    if((!IsPlayerConnected(j)) || (IsPlayerNPC(j)) || (!p_spawned{j})) continue;
      		playAudio(j, 4);
		}
		startGame(area_id);
		return ;
	}
    
    if(preview == 3){
    	new Float:CP[2], position = _random((area_id * 10), (area_id * 10) + 9);

	    CP[0]  = _zones[position][0];
	    CP[1]  = _zones[position][1];
	    CP[0] += (120 * floatsin(0.0, degrees));
	    CP[1] += (-120 * floatcos(0.0, degrees));
	    j = -1;
		while(++j != MAX_PLAYERS){
		    if((!IsPlayerConnected(j)) || (IsPlayerNPC(j)) || (!p_spawned{j})) continue;
			InterpolateCameraPos(j, 	_zones[position][0]+360, _zones[position][1]+62, _zones[position][2]+60,CP[0], CP[1], _zones[position][2]+44, 4999, CAMERA_MOVE);
			InterpolateCameraLookAt(j,	_zones[position][0]-180, _zones[position][1]-5, _zones[position][2]+92,_zones[position][0], _zones[position][1], _zones[position][2]+25, 4999, CAMERA_MOVE);
		}
    }
    
	j = -1;
	
	while(++j != MAX_PLAYERS){
	    if((!IsPlayerConnected(j)) || (IsPlayerNPC(j)) || (!p_spawned{j})) continue;
		playAudio(j, preview);
	}
	
	preview--;
	
	SetTimerEx("previewMode", 1000, false, "i", area_id);
}

startGame(area_id){
	roundEnabled = true;
	round = area_id;
	TextDrawShowForAll(Textdraw0);
    clearObjects();
    deleteVehicles();
    printf("Total objects: %i", countObjects());
    destroyPickups();
    destroy3DLabels();
    TextDrawHideForAll(voteDraw[0]);
 	TextDrawHideForAll(voteDraw[1]);
	new j = -1, Field[128];
	while(++j != sizeof _createPickups){
	    _pickup[j] = CreatePickup(1254, 14, _createPickups[j][0], _createPickups[j][1], _createPickups[j][2] + 0.3, 10);
	    //printf("%i - created: %f, %f, %f", j, _createPickups[j][0], _createPickups[j][1], _createPickups[j][2] + 0.3);
	}
	
	j = -1;
	while(++j != sizeof _fuelZone){
	    _fuelPickup[j] = CreatePickup(1277, 14, _fuelZone[j][0], _fuelZone[j][1], _fuelZone[j][2], 10);
	    _fuelText[j] = Create3DTextLabel("Колонка с топливом.\nОсталось {79a0c1}450{ffffff} литров", -1, _fuelZone[j][0], _fuelZone[j][1], _fuelZone[j][2], 10.0, 10, 0);
        _stantionFuel[j] = float(_random(300, 450));
		//SetPlayerMapIcon( 0, j, _fuelZone[j][0], _fuelZone[j][1], _fuelZone[j][2], 19, 0, MAPICON_GLOBAL );
	}

	for(j = 0; j != sizeof a_info; j++) a_info[j] = 0;

	j = -1;
	while(++j != MAX_PLAYERS){
	    if((IsPlayerNPC(j)) || (!IsPlayerConnected(j)) || (!p_spawned{j})) continue;
	    
	    SetPlayerVirtualWorld(j, 255);
	    
	    SetPVarInt(j, "position", _random((area_id * 10), (area_id * 10) + 9));
	    
		disqualification(j);
        //round_shots[j] = 0;
		SetPVarInt(j, "_inRound", 1);
		SetPVarInt(j, "voted", 1);

		SetPlayerHealth(j, 100.0);

		SetPlayerPos(j, _zones[GetPVarInt(j, "position")][0],_zones[GetPVarInt(j, "position")][1],_zones[GetPVarInt(j, "position")][2]);
		SetPlayerFacingAngle(j, _zones[GetPVarInt(j, "position")][3]);

	    ShowPlayerDialog(j, 3, DIALOG_STYLE_LIST, "Choose car", "Alpha\nBanshee\nBlista Compact\nBuffalo\nBullet\nCheetah\nTurismo\nPhoenix\nSuper GT\nZR-350", "Choose", "");
	}
	format(Field, 128, "Area %i enabled", area_id);
	SendClientMessageToAll(-1, Field);
	_min = ROUND_MINUTES;
	_sec = ROUND_SECONDS;
 	protect = 0;
 	preview = 0;
 	vote_active = false;
	//voteStr = " ";
	vote_time = 0;
}

_random(_minimal, _maximal){//by Seregamil - рандом от минимального к максимальному
	if(_minimal == _maximal || _maximal < _minimal || _maximal < 1 || _minimal < 0) return false;
	new random_value = -1;

    for(new i = 0; i != 1; i = 0){
    	random_value = random(_maximal + 1);
        if((_minimal) < random_value < (_maximal + 1)) break;
    }
    return random_value;
}

public OnGameModeExit(){
	db_close(_db);
	fclose(s_hMap);
	Audio_DestroyTCPServer();
	return 1;
}

public Audio_OnClientConnect(playerid)
{
	return 1;
}

public Audio_OnClientDisconnect(playerid)
{
	return 1;
}


playAudio(playerid, id){
	if(!Audio_IsClientConnected(playerid)) return;
	Audio_Play(playerid, id);
}

public OnPlayerRequestClass(playerid, classid){
	TogglePlayerSpectating(playerid, 0);
	TogglePlayerControllable(playerid,1);
	SetCameraBehindPlayer(playerid);
	SetPlayerInterior(playerid,0);
	SetPlayerPos(playerid, 1236.996582, -1779.051269, 49.262687);
	SetPlayerFacingAngle(playerid, 224.509933);
	SetPlayerCameraLookAt(playerid, 1236.996582, -1779.051269, 49.262687);
	SetPlayerCameraPos(playerid, 1236.996582 + (10 * floatsin(-224.509933, degrees)), -1779.051269 + (10 * floatcos(-224.509933, degrees)), 49.262687);
	return 1;//SpawnPlayer(playerid);
}

public OnPlayerConnect(playerid){

	GetPlayerName(playerid, _name[playerid], MAX_PLAYER_NAME + 1);
	GetPlayerIp(playerid, _ip[playerid], 16);
	new str[300];
	format(str, sizeof str, "banned/_%s", p_name(playerid));

	if(fexist(str)) return Ban(playerid);
	
	for(new j = 0; j != 40; j++) SendClientMessage(playerid, -1, "  ");

    SetPlayerVirtualWorld(playerid, 0);

    ResetPlayerWeapons(playerid);
	total_shots[playerid] = 0;
    j_count[playerid] = 100;
    modificationTime[playerid] = 100.0;
	//round_shots[playerid] = 0;
	Procent[playerid] = CreatePlayerTextDraw(playerid, 557.500000, 82.833343, "100%");
	PlayerTextDrawLetterSize(playerid, Procent[playerid], 0.215625, 1.057500);
	PlayerTextDrawAlignment(playerid, Procent[playerid], 2);
	PlayerTextDrawColor(playerid, Procent[playerid], -1);
	PlayerTextDrawSetShadow(playerid, Procent[playerid], 0);
	PlayerTextDrawSetOutline(playerid, Procent[playerid], 1);
	PlayerTextDrawBackgroundColor(playerid, Procent[playerid], 51);
	PlayerTextDrawFont(playerid, Procent[playerid], 2);
	PlayerTextDrawSetProportional(playerid, Procent[playerid], 1);
	PlayerTextDrawHide(playerid, Procent[playerid]);

	rocketReload[playerid] = CreatePlayerTextDraw(playerid, 608.875000, 81.999992, "usebox");
	PlayerTextDrawLetterSize(playerid, rocketReload[playerid], 0.000000, 1.384720);
	PlayerTextDrawTextSize(playerid, rocketReload[playerid], 495.500000, 0.000000);
	PlayerTextDrawAlignment(playerid, rocketReload[playerid], 1);
	PlayerTextDrawColor(playerid, rocketReload[playerid], 0);
	PlayerTextDrawUseBox(playerid, rocketReload[playerid], true);
	PlayerTextDrawBoxColor(playerid, rocketReload[playerid], -291176199);
	PlayerTextDrawSetShadow(playerid, rocketReload[playerid], 0);
	PlayerTextDrawSetOutline(playerid, rocketReload[playerid], 0);
	PlayerTextDrawFont(playerid, rocketReload[playerid], 0);
	PlayerTextDrawHide(playerid, rocketReload[playerid]);

	modificationProcent[playerid] = CreatePlayerTextDraw(playerid, 557.500000, 105.833343, "100%");
	PlayerTextDrawLetterSize(playerid, modificationProcent[playerid], 0.215625, 1.057500);
	PlayerTextDrawAlignment(playerid, modificationProcent[playerid], 2);
	PlayerTextDrawColor(playerid, modificationProcent[playerid], -1);
	PlayerTextDrawSetShadow(playerid, modificationProcent[playerid], 0);
	PlayerTextDrawSetOutline(playerid, modificationProcent[playerid], 1);
	PlayerTextDrawBackgroundColor(playerid, modificationProcent[playerid], 51);
	PlayerTextDrawFont(playerid, modificationProcent[playerid], 2);
	PlayerTextDrawSetProportional(playerid, modificationProcent[playerid], 1);
	PlayerTextDrawHide(playerid, modificationProcent[playerid]);

	fuelDraw[playerid] = CreatePlayerTextDraw(playerid, 608.266723, 58.666667, "usebox");
	PlayerTextDrawLetterSize(playerid, fuelDraw[playerid], 0.000000, 0.066837);
	PlayerTextDrawTextSize(playerid, fuelDraw[playerid], 546.170043, 0.000000);
	PlayerTextDrawAlignment(playerid, fuelDraw[playerid], 1);
	PlayerTextDrawColor(playerid, fuelDraw[playerid], 0);
	PlayerTextDrawUseBox(playerid, fuelDraw[playerid], true);
	PlayerTextDrawBoxColor(playerid, fuelDraw[playerid], -2003304193);
	PlayerTextDrawSetShadow(playerid, fuelDraw[playerid], 0);
	PlayerTextDrawSetOutline(playerid, fuelDraw[playerid], 0);
	PlayerTextDrawFont(playerid, fuelDraw[playerid], 0);

	modificationReload[playerid] = CreatePlayerTextDraw(playerid, 608.875000, 104.999992, "usebox");
	PlayerTextDrawLetterSize(playerid, modificationReload[playerid], 0.000000, 1.384720);
	PlayerTextDrawTextSize(playerid, modificationReload[playerid], 495.500000, 0.000000);
	PlayerTextDrawAlignment(playerid, modificationReload[playerid], 1);
	PlayerTextDrawColor(playerid, modificationReload[playerid], 0);
	PlayerTextDrawUseBox(playerid, modificationReload[playerid], true);
	PlayerTextDrawBoxColor(playerid, modificationReload[playerid], 0x00960bff);
	PlayerTextDrawSetShadow(playerid, modificationReload[playerid], 0);
	PlayerTextDrawSetOutline(playerid, modificationReload[playerid], 0);
	PlayerTextDrawFont(playerid, modificationReload[playerid], 0);
	PlayerTextDrawHide(playerid, modificationReload[playerid]);

	healthDraw[playerid] = CreatePlayerTextDraw(playerid, 610.483459, 65.916671, "100");
	PlayerTextDrawLetterSize(playerid, healthDraw[playerid], 0.256500, 0.917499);
	PlayerTextDrawAlignment(playerid, healthDraw[playerid], 1);
	PlayerTextDrawColor(playerid, healthDraw[playerid], -16776961);
	PlayerTextDrawSetShadow(playerid, healthDraw[playerid], 0);
	PlayerTextDrawSetOutline(playerid, healthDraw[playerid], 1);
	PlayerTextDrawFont(playerid, healthDraw[playerid], 1);
	PlayerTextDrawSetProportional(playerid, healthDraw[playerid], 1);
    PlayerTextDrawHide(playerid, healthDraw[playerid]);

	rangDraw[playerid] = CreatePlayerTextDraw(playerid, 521.932617, 4.666701, "_");
	PlayerTextDrawLetterSize(playerid, rangDraw[playerid], 0.449999, 1.600000);
	PlayerTextDrawAlignment(playerid, rangDraw[playerid], 1);
	PlayerTextDrawColor(playerid, rangDraw[playerid], -1);
	PlayerTextDrawSetShadow(playerid, rangDraw[playerid], 0);
	PlayerTextDrawSetOutline(playerid, rangDraw[playerid], 1);
	PlayerTextDrawBackgroundColor(playerid, rangDraw[playerid], 117);
	PlayerTextDrawFont(playerid, rangDraw[playerid], 2);
	PlayerTextDrawSetProportional(playerid, rangDraw[playerid], 1);
	PlayerTextDrawHide(playerid, rangDraw[playerid]);

	TextDrawShowForPlayer(playerid, modeVersion);
	TextDrawHideForPlayer(playerid, Textdraw0);
	TextDrawHideForPlayer(playerid, voteDraw[0]);
 	TextDrawHideForPlayer(playerid, voteDraw[1]);
 	new j = 0;
	for(j = 0; j != sizeof ProgressBar; j++) TextDrawHideForPlayer(playerid, ProgressBar[j]);
	SetPVarInt(playerid, "_veh", -1);
 	SetPVarInt(playerid, "_mode", -1);
 	SetPVarInt(playerid, "_inRound", 0);
 	SetPVarInt(playerid, "voted", 0);
	p_spawned{playerid} = false;
	format(str, sizeof str, "SELECT * FROM ACCOUNTS WHERE USERNAME = '%s'", p_name(playerid));
	_db_result = db_query(_db, str);
	if(!db_num_rows(_db_result)){
	    //register
	    db_free_result(_db_result);
	    format(str, sizeof str, "SELECT * FROM ACCOUNTS WHERE IP = '%s'", p_ip(playerid));
	    _db_result = db_query(_db, str);
	    if(!db_num_rows(_db_result)){
	        db_free_result(_db_result);
	    	ShowPlayerDialog(playerid, 0, DIALOG_STYLE_INPUT, "  ", REGISTER_TEXT, "Enter", "Leave");
	    }
	    else{
	        db_free_result(_db_result);
	        ShowPlayerDialog(playerid, 2, DIALOG_STYLE_MSGBOX, "  ", "Multi-Account.", "ZAEBALI","");
	    }
	}
	else{
	    //login
	    db_free_result(_db_result);
	    ShowPlayerDialog(playerid, 1, DIALOG_STYLE_INPUT, "  ", "{ffffff}Добро пожаловать\nДля начала игры рекомендую тебе ввести свой пароль.", "Enter", "Leave");
	}
	TogglePlayerSpectating(playerid, 1);
	TogglePlayerControllable(playerid,0);
	SendClientMessage(playerid, -1, "Это открытое тестирование мода. Для запуска режима необходимо 2 игрока");
	SendClientMessage(playerid, -1, "По всем вопросам и предложениям стучим в скайп: Seregamil");
	return 1;
}

public OnPlayerDisconnect(playerid, reason){
    SetPlayerVirtualWorld(playerid, 0);
    PlayerTextDrawDestroy(playerid, healthDraw[playerid]);
    PlayerTextDrawDestroy(playerid, rangDraw[playerid]);
	PlayerTextDrawDestroy(playerid, Procent[playerid]);
	PlayerTextDrawDestroy(playerid, modificationProcent[playerid]);
	PlayerTextDrawDestroy(playerid, fuelDraw[playerid]);
	PlayerTextDrawDestroy(playerid, rocketReload[playerid]);
	PlayerTextDrawDestroy(playerid, modificationReload[playerid]);
	//round_shots[playerid] = 0;
    TogglePlayerSpectating(playerid, 0);
	TogglePlayerControllable(playerid, 1);

    j_count[playerid] = 100;
    modificationTime[playerid] = 100.0;

	p_spawned{playerid} = false;

    disqualification(playerid);
    
    new str[200];
    format(str, 200, "UPDATE ACCOUNTS SET MONEY = '%i' SHOTS = '%i' WHERE USERNAME = '%s'", GetPlayerMoney(playerid), p_name(playerid), total_shots[playerid]);
    db_query(_db, str);
	return 1;
}

public OnPlayerSpawn(playerid){
    SetPlayerVirtualWorld(playerid, 0);
    TogglePlayerClock(playerid, true);
    TogglePlayerSpectating(playerid, 0);
    p_spawned{playerid} = true;
    updateRangs(playerid);
	PlayerTextDrawShow(playerid, rangDraw[playerid]);
    TextDrawShowForPlayer(playerid, Textdraw0);

	disqualification(playerid);

	SetPlayerPos(playerid, 2244.2566,2523.7280,10.8203);
	SetPlayerFacingAngle(playerid, 102.3370);
	SendClientMessage(playerid, -1, "Для начала голосования нажмите клавишу 'Y'");
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason){
    //SendDeathMessage(INVALID_PLAYER_ID, playerid, 47);
    //PlayAudioStreamForPlayer(playerid, "http://seregamil.hol.es/DeathRace/wasted.mp3");

    playAudio(playerid, 9);
	return 1;
}

public OnVehicleDeath(vehicleid, killerid){
	new u_id = -1;
	if(roundEnabled){
		new j = -1;
		while(++j != MAX_PLAYERS){
		    if((IsPlayerNPC(j)) || (!IsPlayerConnected(j)) || (GetPVarInt(j,"_veh") != vehicleid)) continue;
			u_id = j;
			break;
		}
	}
	if(u_id != -1) {
		disqualification(u_id);
        CallLocalFunction("OnUserDeath", "i", u_id);
	}
    clearVehicleObjects(vehicleid);
	DestroyVehicle(vehicleid);
	return 1;
}

public OnUserDeath(playerid){
	/*new str[128];
	format(str, 128, "Игрок %s погиб в раунде", p_name(playerid));
	SendClientMessageToAll(-1, str);*/
}

public OnPlayerText(playerid, text[]){
	if(!p_spawned{playerid}) return false;
	return true;
}

public OnPlayerCommandText(playerid, cmdtext[]){
	dcmd(help, 4, cmdtext);
	//dcmd(vote, 4, cmdtext);
	//dcmd(dm, 2, cmdtext);
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, -1,"Usage: \"/help\"");
	dcmd(kick, 4, cmdtext);
	dcmd(ban, 3, cmdtext);
	dcmd(add, 3, cmdtext);
	dcmd(diss, 4, cmdtext);
	dcmd(enable,6,cmdtext);
	return SendClientMessage(playerid, -1,"Usage: \"/a_help\" or \"/help\"");
}

dcmd_diss(playerid, params[]){
	#pragma unused playerid
	new localuser = strval(params);
	if((!IsPlayerConnected(localuser)) || (!GetPVarInt(localuser, "_inRound")) || (!p_spawned{localuser})) return true;
	disqualification(localuser);
	SetPlayerPos(localuser, 2244.2566,2523.7280,10.8203);
	new str[128];
	format(str, 128, "Игрок %s был дисквалифицирован.", p_name(localuser));
	SendClientMessageToAll(-1, str);
	return true;
}

dcmd_add(playerid, params[]){
	#pragma unused playerid
    addUser(strval(params));
    return true;
}

/*dcmd_vote(playerid, params[]){
	#pragma unused params
	if(roundEnabled || GetPVarInt(playerid, "voted")) return true;
	new str[256];
	for( new j = 0; j!=sizeof a_name; j++) format(str, sizeof str, "%s%i) - %s", str, (j + 1), a_name[j]);
	return ShowPlayerDialog(playerid, 5, DIALOG_STYLE_LIST, "Choose area", str, "Vote", "Exit");
}*/

/*
dcmd_dm(playerid, params[]){
	if(GetPVarInt(playerid, "_inRound")) return false;
	if(IsPlayerInAnyVehicle(playerid)) return false;
	if(!p_spawned{playerid}) return false;
	if(!strlen(params)) return SendClientMessage(playerid, -1, "Usage: \"/dm [1-3]\"");
	if( 1 > strval(params) > 3) return SendClientMessage(playerid, -1, "Usage: \"/dm [1-3]\"");
	switch(strlen(params)){
	    case 1: return true;
	    case 2: return true;
	    case 3: return true;
	}
	return true;
}*/

dcmd_help(playerid, params[]){
	#pragma unused params
	return ShowPlayerDialog(playerid, 255, DIALOG_STYLE_MSGBOX, "  ", "{ffffff}Информация: \n\tСвязь с создателем по skype: Seregamil\n\tЭто лишь тестовая версия мода и все будет обновляться\n\tЕсли нашли косяк или есть идеи - пишем в скайп.\nЧтобы поиграть нужно не меньше чем 2 игрока.", "oo", "");
}

dcmd_enable(playerid, params[]){
	#pragma unused playerid
	#pragma unused params
	preview = 3;
	previewMode(_random(0, (sizeof(_zones) / 10)) - 1);
	return true;
}

dcmd_kick(playerid, params[]){
	if(!strlen(params)) return SendClientMessage(playerid, -1,"/kick userid");
	if(!IsPlayerConnected(strval(params))) return SendClientMessage(playerid, -1, "Invalid userid");
	new str[128], userid = strval(params);
	format(str, 128, "You are kicked from this server. Admin: %s", p_name(playerid));
	SendClientMessage(userid, -1, str);

	format(str, 128, "%s - kicked.", p_name(userid));
	SendClientMessage(playerid, -1, str);

	printf("%s kicked %s", p_name(playerid), p_name(userid));

	return Kick(userid);
}

dcmd_ban(playerid, params[]){
	if(!strlen(params)) return SendClientMessage(playerid, -1,"/ban userid");
	if(!IsPlayerConnected(strval(params))) return SendClientMessage(playerid, -1, "Invalid userid");
	new str[128], userid = strval(params);
	format(str, 128, "You are banned from this server. Admin: %s", p_name(playerid));
	SendClientMessage(userid, -1, str);
	
	format(str, 128, "%s - banned.", p_name(userid));
	SendClientMessage(playerid, -1, str);
	
	printf("%s banned %s", p_name(playerid), p_name(userid));
	
	_ban(userid);
	return true;
}

_ban(playerid){
	new str[70];
	format(str, 70, "banned/_%s", p_name(playerid));
	if(!fexist(str)){
		ini_createFile(str);
	}
	return Ban(playerid);
}

public OnPlayerStateChange(playerid, newstate, oldstate){
	if(newstate == PLAYER_STATE_WASTED){
	    p_spawned{playerid} = false;
	}
	//if(!roundEnabled) return true;
	if(oldstate == PLAYER_STATE_DRIVER && GetPVarInt(playerid, "_inRound") && GetPVarInt(playerid, "_veh") != -1){
 		PutPlayerInVehicle(playerid, GetPVarInt(playerid, "_veh"), 0);
	}
	if(newstate == PLAYER_STATE_DRIVER){
		for(new j = 0; j != sizeof ProgressBar; j++) TextDrawShowForPlayer(playerid, ProgressBar[j]);
		PlayerTextDrawShow(playerid, Procent[playerid]);
		PlayerTextDrawShow(playerid, modificationProcent[playerid]);
		PlayerTextDrawShow(playerid, fuelDraw[playerid]);
		PlayerTextDrawShow(playerid, rocketReload[playerid]);
		PlayerTextDrawShow(playerid, modificationReload[playerid]);
		new engine,lights,alarm,doors,bonnet,boot,objective;
		GetVehicleParamsEx(GetPlayerVehicleID(playerid),engine,lights,alarm,doors,bonnet,boot,objective);
		if(!engine) SendClientMessage(playerid, -1, "Чтобы завести двигатель нажмите \"2\"");
		GivePlayerWeapon(playerid, 35, 999999);
	}
	else{
		for(new j = 0; j != sizeof ProgressBar; j++) TextDrawHideForPlayer(playerid, ProgressBar[j]);
		PlayerTextDrawHide(playerid, Procent[playerid]);
		PlayerTextDrawHide(playerid, modificationProcent[playerid]);
		PlayerTextDrawHide(playerid, fuelDraw[playerid]);
		PlayerTextDrawHide(playerid, rocketReload[playerid]);
		PlayerTextDrawHide(playerid, modificationReload[playerid]);

		ResetPlayerWeapons(playerid);
	}
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid){
	if(!roundEnabled)  return true;
	if(!IsPlayerInAnyVehicle(playerid)) return true;
	new j = -1, vehicleid = GetPlayerVehicleID(playerid);
	while(++j != sizeof _fuelPickup){
	    if(pickupid != _fuelPickup[j]) continue;
	    if(fuelCar[vehicleid] != 100.0) {
	        new Float: calculate = (_stantionFuel[j] - (100.0 - fuelCar[vehicleid]));
	        if(calculate <= 0){//если при подсчете на станции бензина меньше чем нам нужно
				fuelCar[vehicleid] += _stantionFuel[j];//отдадим все топливо в машину
				_stantionFuel[j] = 0.0;//поставим топливо на станции на 0
	        }
	        else{
	            _stantionFuel[j] -= (100.0 - fuelCar[vehicleid]);//заберем у станции нужное нам топливо
	            fuelCar[vehicleid] = 100.0;//поставим кол-во топлива в машине на 100
	        }
		}
		
		new str[128];
		format(str, sizeof str, "Колонка с топливом.\nОсталось {79a0c1}%i{ffffff} литров", floatround(_stantionFuel[j]));
		Update3DTextLabelText(_fuelText[j], -1, str);
		
	    DestroyPickup(_fuelPickup[j]);
	    _fuelPickup[j] = CreatePickup(1277, 14, _fuelZone[j][0], _fuelZone[j][1], _fuelZone[j][2], 10);
	    return true;
	}
	new Float: _x, Float: _y, Float: _z;
	switch(random(3)){
	    case 0: {
	    	GetVehiclePos(vehicleid, _x, _y, _z);
			CreateExplosion(_x, _y, _z + 1.0, 2, EXPLOSION_RADIUS);
			SendClientMessage(playerid, -1, "Boooom! :p");
		}
	    case 1: {
			RepairVehicle(vehicleid), SetVehicleHealth(vehicleid, ROUND_VEHICLE_HEALTH);
			SendClientMessage(playerid, -1, "Vehicle fixed.");
		}
	    case 2: {
		    GetVehicleVelocity(vehicleid, _x,  _y, _z);
		    SetVehicleVelocity(vehicleid, _x,  _y, 0.4);
		    SendClientMessage(playerid, -1, "Fly man, fly!");
	    }
	}
	DestroyPickup(_pickup[pickupid]);
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys){
	if(!roundEnabled) {
	    if(newkeys & KEY_YES && !GetPVarInt(playerid, "voted") && getAllUsersConnected() >= MINIMAL_USERS){
			new str[256];
			for( new j = 0; j!=sizeof a_name; j++) format(str, sizeof str, "%s%i) - %s\n", str, (j + 1), a_name[j]);
			return ShowPlayerDialog(playerid, 5, DIALOG_STYLE_LIST, "Choose area", str, "Vote", "Exit");
	    }
	}
	else{
	    new vehicleid = GetPlayerVehicleID(playerid);
	    if(newkeys & KEY_SUBMISSION && IsPlayerInAnyVehicle(playerid) && vehicleid == GetPVarInt(playerid, "_veh") && GetPVarInt(playerid, "_inRound") == 1 && fuelCar[vehicleid] > 0.1){
            new engine,lights,alarm,doors,bonnet,boot,objective;
			GetVehicleParamsEx(vehicleid,engine,lights,alarm,doors,bonnet,boot,objective);
			if(!engine) SetVehicleParamsEx(vehicleid,1,1,alarm,doors,bonnet,boot,objective);
			else SetVehicleParamsEx(vehicleid,0,0,alarm,doors,bonnet,boot,objective);
	    }
		new Float: position[2][3], _rocket ;
		if(newkeys & 1 && IsPlayerInAnyVehicle(playerid) && vehicleid == GetPVarInt(playerid, "_veh") && GetPVarInt(playerid, "_inRound") == 1 && modificationTime[playerid] == 100.0){
			switch(GetPVarInt(playerid, "_mode")){
			    case 0:{// fast rocket
					GetVehiclePos(vehicleid, position[0][0],position[0][1],position[0][2]);

					_rocket = CreateObject(345, position[0][0],position[0][1],position[0][2]+0.3, 0.0,0.0,0.0);

					PositionFromVehicleOffset(vehicleid,0.0,500.0,0.0,position[1][0],position[1][1],position[1][2]);
					MoveObject(_rocket, position[1][0],position[1][1],position[1][2], (ROCKET_SPEED + ROCKET_SPEED * 0.5));

			        _objectOwn[_rocket] = playerid;

			        modificationTime[playerid] = 0.0;

			        CallLocalFunction("OnPlayerUsedModification", "ii", playerid, 0);
			        CallLocalFunction("OnPlayerShotRocket", "i", playerid);

					SetTimerEx("_rocketUpdate", 50, false, "i", _rocket);
			    }
			    case 1:{//hydra
			        modificationTime[playerid] = 0.0;
				    GetVehicleVelocity(vehicleid, position[0][0],position[0][1],position[0][2]);
				    SetVehicleVelocity(vehicleid, position[0][0],position[0][1], 0.4);
				    CallLocalFunction("OnPlayerUsedModification", "ii", playerid, 1);
			    }
			    case 2:{//quick reload

					GetVehiclePos(vehicleid, position[0][0],position[0][1],position[0][2]);

					_rocket = CreateObject(345, position[0][0],position[0][1],position[0][2]+0.3, 0.0,0.0,0.0);

					PositionFromVehicleOffset(vehicleid,0.0,500.0,0.0,position[1][0],position[1][1],position[1][2]);
					MoveObject(_rocket, position[1][0],position[1][1],position[1][2], ROCKET_SPEED);

			        _objectOwn[_rocket] = playerid;

			        modificationTime[playerid] = 0.0;

			        CallLocalFunction("OnPlayerUsedModification", "ii", playerid, 2);
			        CallLocalFunction("OnPlayerShotRocket", "i", playerid);

					SetTimerEx("_rocketUpdate", 50, false, "i", _rocket);
			    }
			}
		}
		if(newkeys & 4 && j_count[playerid] == 100 && IsPlayerInAnyVehicle(playerid) && vehicleid == GetPVarInt(playerid, "_veh") && GetPVarInt(playerid, "_inRound") == 1){

			GetVehiclePos(vehicleid, position[0][0],position[0][1],position[0][2]);

			_rocket = CreateObject(345, position[0][0],position[0][1],position[0][2]+0.3, 0.0,0.0,0.0);

			PositionFromVehicleOffset(vehicleid,0.0,500.0,0.0,position[1][0],position[1][1],position[1][2]);
			MoveObject(_rocket, position[1][0],position[1][1],position[1][2], ROCKET_SPEED);

	        _objectOwn[_rocket] = playerid;

	        j_count[playerid] = 0;

	        CallLocalFunction("OnPlayerShotRocket", "i", playerid);

			SetTimerEx("_rocketUpdate", 50, false, "i", _rocket);
		}
	}
	return 1;
}

public OnPlayerUsedModification(playerid, modification_id){
	/*new str[128];
	format(str, 128, "Вы использовали модификацию %s", modification_name[modification_id]);
	SendClientMessage(playerid, -1, str);*/
}

public OnPlayerShotRocket(playerid){
	//SendClientMessage(playerid, -1, "OnPlayerShotRocket(ты)");
	//PlayAudioStreamForPlayer(playerid, "http://seregamil.hol.es/DeathRace/missile_launch.wav");
	playAudio(playerid, 7);
}

Float:GetPointZPos(const Float:fX, const Float:fY, &Float:fZ = 0.0)
{
	if(!((-3000.0 < fX < 3000.0) && (-3000.0 < fY < 3000.0))) return 0.0;

	new afZ[1];
	fseek(s_hMap, ((6000 * (-floatround(fY, floatround_tozero) + 3000) + (floatround(fX, floatround_tozero) + 3000)) << 1));
	fblockread(s_hMap, afZ);

	return (fZ = ((afZ[0] >>> 16) * 0.01));
}

public _rocketUpdate(objectid){
	if(!IsValidObject(objectid))
		return;

	new j = -1, Float: _pos[3];
	GetObjectPos(objectid, _pos[0], _pos[1], _pos[2]);

	new Float: pointZ = GetPointZPos(_pos[0], _pos[1]);
	if(_pos[2] < pointZ){
		CreateExplosion(_pos[0], _pos[1], _pos[2], 2, EXPLOSION_RADIUS);
		_objectOwn[objectid] = INVALID_PLAYER_ID;
		DestroyObject(objectid);
	    return;
	}

	new Float: pos_[3];

	while(++j != MAX_VEHICLES){
	    if(!IsValidVehicle(j)) continue;
	    if(j == GetPVarInt(_objectOwn[objectid], "_veh")) continue;
	    GetVehiclePos(j, pos_[0], pos_[1], pos_[2]);
	    if((floatsqroot(floatpower(floatabs(floatsub(pos_[0], _pos[0])), 2) + floatpower(floatabs(floatsub(pos_[1], _pos[1])), 2) + floatpower(floatabs(floatsub(pos_[2], _pos[2])), 2))) >= 4) continue;
        CreateExplosion(pos_[0], pos_[1], pos_[2], 2, EXPLOSION_RADIUS);
        for(new i = 0; i!=MAX_PLAYERS; i++){
            if(!IsPlayerConnected(i)) continue;
            if(!p_spawned{i}) continue;
            if(!GetPVarInt(i, "_inRound")) continue;
            if(!IsPlayerInAnyVehicle(i)) continue;
            if(GetPlayerVehicleID(i) != j) continue;
            CallLocalFunction("OnRocketTakeDamage", "iii", _objectOwn[objectid], i, j);
            break;
        }
        _objectOwn[objectid] = INVALID_PLAYER_ID;
        DestroyObject(objectid);
        return;
	}

	if(!IsValidObject(objectid)){
	    _objectOwn[objectid] = INVALID_PLAYER_ID;
	    return;
	}
		
	SetTimerEx("_rocketUpdate", 50, false, "i", objectid);
}

public OnRocketTakeDamage(playerid, owner_vehicle, vehicleid){
	/*new str[128];
	format(str, 128, "В машину юзера %s попала ракета от игрока %s[%i]", p_name(owner_vehicle), p_name(playerid), playerid);
	SendClientMessageToAll(-1, str);*/
	total_shots[playerid] ++;
	//round_shots[playerid] ++;
    updateRangs(playerid);
}

updateRangs(playerid){
	new str[72];
	switch(total_shots[playerid]){
	    case 0..50: format(str, 72, "~y~]~g~~h~]]]]");
	    case 51..150: format(str, 72, "~y~]]~g~~h~]]]");
	    case 151..273: format(str, 72, "~y~]]]~g~~h~]]");
	    case 274..568: format(str, 72, "~y~]]]]~g~~h~]");
	    default: format(str, 72, "~y~]]]]]");
	}
	PlayerTextDrawSetString(playerid, rangDraw[playerid], str);
	//PlayerTextDrawShow(playerid, rangDraw[playerid]);
}

public OnObjectMoved(objectid){
	new Float: _pos[3];

	GetObjectPos(objectid, _pos[0], _pos[1], _pos[2]);
	CreateExplosion(_pos[0], _pos[1], _pos[2], 2, EXPLOSION_RADIUS);
	
	DestroyObject(objectid);
    return 1;
}

public OnRconLoginAttempt(ip[], password[], success){
	return 1;
}

public OnPlayerUpdate(playerid){
	_afk[playerid] = GetTickCount();
	new vehicleid = GetPlayerVehicleID(playerid);
	if(roundEnabled && GetPVarInt(playerid, "_inRound") && IsPlayerInAnyVehicle(playerid) && vehicleid == GetPVarInt(playerid, "_veh")){

		new engine,lights,alarm,doors,bonnet,boot,objective;
		GetVehicleParamsEx(vehicleid,engine,lights,alarm,doors,bonnet,boot,objective);
		if(engine){
			fuelCar[vehicleid] -= 0.020;

			PlayerTextDrawDestroy(playerid, fuelDraw[playerid]);
			
			fuelDraw[playerid] = CreatePlayerTextDraw(playerid, 549.764221 + (fuelCar[vehicleid] * 0.58503502), 58.666667, "usebox");
			PlayerTextDrawLetterSize(playerid, fuelDraw[playerid], 0.000000, 0.066837);
			PlayerTextDrawTextSize(playerid, fuelDraw[playerid], 546.170043, 0.000000);
			PlayerTextDrawAlignment(playerid, fuelDraw[playerid], 1);
			PlayerTextDrawColor(playerid, fuelDraw[playerid], 0);
			PlayerTextDrawUseBox(playerid, fuelDraw[playerid], true);
			PlayerTextDrawBoxColor(playerid, fuelDraw[playerid], -2003304193);
			PlayerTextDrawSetShadow(playerid, fuelDraw[playerid], 0);
			PlayerTextDrawSetOutline(playerid, fuelDraw[playerid], 0);
			PlayerTextDrawFont(playerid, fuelDraw[playerid], 0);

			PlayerTextDrawShow(playerid, fuelDraw[playerid]);

			if(fuelCar[vehicleid] <= 0.0){
			    SetVehicleParamsEx(vehicleid,0,0,alarm,doors,bonnet,boot,objective);
			    SendClientMessage(playerid, -1, "Двигатель заглох, я тебя поздравляю.");
			}
		}
		new Float:health;
		GetVehicleHealth(vehicleid, health);
		if(health > 200.0) SetPlayerHealth(playerid, floatround(health / 150.0));

		new str[27];
		format(str, sizeof str, "%i", floatround(health / 150.0));
		PlayerTextDrawSetString(playerid,  healthDraw[playerid], str);
		PlayerTextDrawShow(playerid, healthDraw[playerid]);

		if(j_count[playerid] != 100){
		    j_count[playerid] += 2;

		    PlayerTextDrawDestroy(playerid, rocketReload[playerid]);

			rocketReload[playerid] = CreatePlayerTextDraw(playerid, 495.500000 + (float(j_count[playerid]) * 1.13375), 81.999992, "_");
			PlayerTextDrawLetterSize(playerid, rocketReload[playerid], 0.000000, 1.384720);
			PlayerTextDrawTextSize(playerid, rocketReload[playerid], 495.500000, 0.000000);
			PlayerTextDrawAlignment(playerid, rocketReload[playerid], 1);
			PlayerTextDrawUseBox(playerid, rocketReload[playerid], true);
			PlayerTextDrawBoxColor(playerid, rocketReload[playerid], 0xff8800FF);

			PlayerTextDrawShow(playerid, rocketReload[playerid]);

			//new str[27];
			format(str,sizeof str,"Simple rocket: %i%", j_count[playerid]);
			PlayerTextDrawSetString(playerid, Procent[playerid], str);
		}
		if(modificationTime[playerid] != 100){
		    modificationTime[playerid] += (GetPVarInt(playerid, "_mode") == 2 ? (2.5) : (0.5));

			PlayerTextDrawDestroy(playerid, modificationReload[playerid]);

			modificationReload[playerid] = CreatePlayerTextDraw(playerid, 495.500000 + (modificationTime[playerid] * 1.13375), 104.999992, "_");
			PlayerTextDrawLetterSize(playerid, modificationReload[playerid], 0.000000, 1.384720);
			PlayerTextDrawTextSize(playerid, modificationReload[playerid], 495.500000, 0.000000);
			PlayerTextDrawAlignment(playerid, modificationReload[playerid], 1);
			PlayerTextDrawUseBox(playerid, modificationReload[playerid], true);
			PlayerTextDrawBoxColor(playerid, modificationReload[playerid], 0x00960bff);

			PlayerTextDrawShow(playerid, modificationReload[playerid]);

			//new str[27];
		 	format(str,sizeof str,"%s: %i%", modification_name[GetPVarInt(playerid, "_mode")],floatround(modificationTime[playerid]));
			PlayerTextDrawSetString(playerid, modificationProcent[playerid], str);
		}
	}
	else{
	    PlayerTextDrawHide(playerid, healthDraw[playerid]);
	}
	return true;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]){
	switch(dialogid){
	    case 0:{//register
	        if(!response) return Kick(playerid);
			if(!isValidPassword(inputtext)) return ShowPlayerDialog(playerid, 0, DIALOG_STYLE_INPUT, "  ", REGISTER_TEXT, "Enter", "Leave");
			new str[300];
			format(str, 300, "INSERT INTO ACCOUNTS(USERNAME, IP, PASSWORD, MONEY, SHOTS)VALUES('%s', '%s', '%s', '0', '0')", p_name(playerid), p_ip(playerid), inputtext);
			db_query(_db, str);
			p_spawned{playerid} = false;
			format(str, 70, "[!-!] User %s is connected.", p_name(playerid));
			SendClientMessageToAll(-1,str);
			total_shots[playerid] = 0;
			TogglePlayerSpectating(playerid, 0);
			TogglePlayerControllable(playerid,1);
			return 1;
	    }
	    case 1:{//login
	        if(!response) return Kick(playerid);
	        if(!strlen(inputtext)) return ShowPlayerDialog(playerid, 1, DIALOG_STYLE_INPUT, "  ", "{ffffff}Добро пожаловать\nДля начала игры рекомендую тебе ввести свой пароль.", "Enter", "Leave");
			new str[500];
			format(str, 500, "SELECT * FROM ACCOUNTS WHERE USERNAME = '%s' AND PASSWORD = '%s'", p_name(playerid), inputtext);
			_db_result = db_query(_db, str);
			if(!db_num_rows(_db_result)){
			    db_free_result(_db_result);
			    return ShowPlayerDialog(playerid, 1, DIALOG_STYLE_INPUT, "  ", "{ffffff}Добро пожаловать\nДля начала игры рекомендую тебе ввести свой пароль.", "Enter", "Leave");
			}
			new Field[50];
			
			db_get_field_assoc(_db_result, "MONEY", Field, 50), ResetPlayerMoney(playerid), GivePlayerMoney(playerid, strval(Field));
			db_get_field_assoc(_db_result, "SHOTS", Field, 50), total_shots[playerid] = strval(Field);
			updateRangs(playerid);
			p_spawned{playerid} = false;
			format(str, 70, "[!-!] User %s is connected.", p_name(playerid));
			SendClientMessageToAll(-1,str);

			db_free_result(_db_result);
			TogglePlayerSpectating(playerid, 0);
			TogglePlayerControllable(playerid,1);
			return 1;
	    }
	    case 2:{//multiaccount
	        return Kick(playerid);
	    }
	    case 3:{//choose car
	        if(!response) return ShowPlayerDialog(playerid, 3, DIALOG_STYLE_LIST, "Choose car", "Alpha\nBanshee\nBlista Compact\nBuffalo\nBullet\nCheetah\nTurismo\nPhoenix\nSuper GT\nZR-350", "Choose", "");
			SetPVarInt(playerid,"_veh",vehicles[listitem]);
	        return ShowPlayerDialog(playerid, 4, DIALOG_STYLE_LIST, "Choose modification", "Fast rocket\nHydraulics\nQuick Reload" ,"Choose","Canel");
	    }
	    case 4:{
	        if(!response) return ShowPlayerDialog(playerid, 3, DIALOG_STYLE_LIST, "Choose car", "Alpha\nBanshee\nBlista Compact\nBuffalo\nBullet\nCheetah\nTurismo\nPhoenix\nSuper GT\nZR-350", "Choose", "");
			SetPVarInt(playerid, "_mode", listitem);
			SetPlayerVirtualWorld(playerid, 0);
			return createVehicle(playerid, GetPVarInt(playerid,"_veh"), _zones[GetPVarInt(playerid, "position")][0],_zones[GetPVarInt(playerid, "position")][1],_zones[GetPVarInt(playerid, "position")][2],_zones[GetPVarInt(playerid, "position")][3],random(128),random(128));
	    }
	    case 5:{//vote mode
	        if(!response) return true;
	        SetPVarInt(playerid, "voted", 1);
	        if(!vote_active) {
				vote_active = true;
				vote_time = 15;
				TextDrawShowForAll(voteDraw[0]);
 				TextDrawShowForAll(voteDraw[1]);
			}
	        a_info[listitem] ++;
	        //if(a_info[listitem] != 1)
	        //format(voteStr, sizeof voteStr, "%s~w~%s ~y~(%i)~n~", voteStr, a_name[listitem], a_info[listitem]);
	        //TextDrawSetString(voteDraw[1], voteStr);
	        new str[128];
	        format(str, 128, "Игрок %s проголосовал за %i арену (%s)", p_name(playerid), (listitem + 1), a_name[listitem]);
	        return SendClientMessageToAll(-1, str);
	    }
	}
	return 1;
}

isValidPassword(password[]){
	if(!strlen(password)) return false;
	new j = -1;
	while(++j != strlen(password)){
	    switch(password[j]){
			case '0'..'9', 'A'..'Z', 'a'..'z': continue;
			default: return false;
	    }
	}
	return true;
}

createVehicle(playerid, vehicleid, Float:_x, Float: _y, Float: _z, Float: _a, clr1, clr2){
	if((!roundEnabled) || (!GetPVarInt(playerid, "_inRound"))){
		ShowPlayerDialog(playerid, -1, 0, "", "", "", "");
	    SetCameraBehindPlayer(playerid);
	    SetPlayerPos(playerid, 2244.2566,2523.7280,10.8203);
	    SetPVarInt(playerid, "voted", 0);
		disqualification(playerid);
	    return true;
	}
	new _car = CreateVehicle(vehicleid, _x,  _y,  _z,  _a, clr1, clr2, 9999999);
	SetVehicleParamsEx(_car,0,0,0,0,0,0,0);

	fuelCar[_car] = 100.0;

  	clearVehicleObjects(_car);

	_carObjects[_car][0] = CreateObject(3786,0,0,-1000,0,0,0,100);
	_carObjects[_car][1] = CreateObject(3786,0,0,-1000,0,0,0,100);

	AttachObjectToVehicle(_carObjects[_car][0], _car, -1.200000,0.000000,-0.075000,43.200008,0.000001,269.999877);
	AttachObjectToVehicle(_carObjects[_car][1], _car, 1.200000,0.000000,-0.075000,43.200008,0.000001, 269.999877);

    j_count[playerid] = 100;
	modificationTime[playerid] = 100.0;

	SetPVarInt(playerid, "_veh", _car);
	SetVehicleHealth(_car, ROUND_VEHICLE_HEALTH);

	for(new j = 0; j != 40; j++) SendClientMessage(playerid, -1, "  ");
	
	SendClientMessage(playerid, -1, "Выстрел ракетой: ЛКМ");
	SendClientMessage(playerid, -1, "Использование модификации: CTRL, если вы что-то меняли, то смотрите сами.");
	SendClientMessage(playerid, -1, "Выход из транспортного средства запрещен.");
	SendClientMessage(playerid, -1, "При выходе в АФК больше чем на 5 секунд вы будете дисквалифицированы.");
	SendClientMessage(playerid, -1, "Если решите поплавать то будете исключены из раунда.");

	SetVehicleVirtualWorld(_car, 10);
	SetPlayerVirtualWorld(playerid, 10);

	PutPlayerInVehicle(playerid, GetPVarInt(playerid, "_veh"), 0);

	PlayerTextDrawSetString(playerid, modificationProcent[playerid], "Protected");
	PlayerTextDrawSetString(playerid, Procent[playerid], "Protected");

	GivePlayerWeapon(playerid,  35, 999999);
	return true;
}

clearVehicleObjects(vehicleid){
	DestroyObject(_carObjects[vehicleid][0]);
	DestroyObject(_carObjects[vehicleid][1]);
}

clearObjects(){
	for(new j = 0; j!=MAX_OBJECTS;j++){
		DestroyObject(j);
	}
}

countObjects(){
	new j = 0;
	for(new i = 0; i!=MAX_OBJECTS;i++){
	    if(!IsValidObject(i)) continue;
	    j++;
	}
	return j;
}

deleteVehicles(){
	for(new j = 0; j!=MAX_VEHICLES;j++){
		DestroyVehicle(j);
		fuelCar[j] = 0.0;
	}
}

setWin(){
	//прошлись по игрокам и повреждениям, выдали всем бонусы, победителя вывели в чат или ТД
    destroyPickups();
    destroy3DLabels();
    deleteVehicles();
	TextDrawHideForAll(voteDraw[0]);
 	TextDrawHideForAll(voteDraw[1]);
 	//voteStr = " ";
	TextDrawShowForAll(Textdraw0);
	vote_active = false;
	vote_time = 0;
	roundEnabled = false;
	_min = MINUTES_TIME;
	_sec = SECONDS_TIME;
	new j = -1;
	while(++j != MAX_PLAYERS){
	    if((IsPlayerNPC(j)) || (!IsPlayerConnected(j)) || (!p_spawned{j})) {
	        continue;
	    }
	    ShowPlayerDialog(j, -1, 0, "", "", "", "");
	    SetCameraBehindPlayer(j);
	    SetPlayerPos(j, 2244.2566,2523.7280,10.8203);
	    SetPVarInt(j, "voted", 0);
	    playAudio(j, 8);
		disqualification(j);
	}

	for(j = 0; j != sizeof a_info; j++) a_info[j] = 0;
	for(j = 0; j != sizeof ProgressBar; j++) TextDrawHideForAll(ProgressBar[j]);
	SendClientMessageToAll(-1, "Раунд остановлен");
	clearObjects();
}

disqualification(u_id){
    DestroyVehicle(GetPVarInt(u_id, "_veh"));
    SetPlayerVirtualWorld(u_id, 0);
	SetPVarInt(u_id,"_veh",-1);
	SetPVarInt(u_id, "_mode", -1);
	SetPVarInt(u_id, "_inRound", 0);
	SetPlayerVirtualWorld(u_id, 0);
	SetPlayerHealth(u_id, 100.0);
	ResetPlayerWeapons(u_id);
	j_count[u_id] = 100 ;
	modificationTime[u_id] = 100.0;
	new j = 0;
	for(j = 0; j != sizeof ProgressBar; j++) TextDrawHideForPlayer(u_id, ProgressBar[j]);
	PlayerTextDrawHide(u_id, Procent[u_id]);
	PlayerTextDrawHide(u_id, modificationProcent[u_id]);
	PlayerTextDrawHide(u_id, fuelDraw[u_id]);
	PlayerTextDrawHide(u_id, rocketReload[u_id]);
	PlayerTextDrawHide(u_id, modificationReload[u_id]);
	TogglePlayerSpectating(u_id, 0);
	TogglePlayerControllable(u_id,1);
}

getAllUsersConnected(){
	new j = -1, total_users = 0;
	while(++j != MAX_PLAYERS){
	    if( ( !IsPlayerConnected(j) ) ||( IsPlayerNPC(j) ) || ( !p_spawned{j} ) ) continue;
	    total_users++;
	}
	return total_users;
}

getAllUsersInRound(){
	new j = -1, total_users = 0;
	while(++j != MAX_PLAYERS){
	    if( ( !IsPlayerConnected(j) ) ||( IsPlayerNPC(j) ) || ( !p_spawned{j} ) || ( !GetPVarInt(j, "_inRound") )) continue;
	    total_users++;
	}
	return total_users;
}

addUser(playerid){
	if((!roundEnabled) || (GetPVarInt(playerid, "_inRound")) || (IsPlayerNPC(playerid)) || (!p_spawned{playerid}) || (!IsPlayerConnected(playerid))) return;
	SetPlayerVirtualWorld(playerid, 255);

	SetPVarInt(playerid, "position", _random((round * 10), (round * 10) + 9));

	disqualification(playerid);

	SetPVarInt(playerid, "_inRound", 1);
	SetPVarInt(playerid, "voted", 1);

	SetPlayerHealth(playerid, 100.0);

	SetPlayerPos(playerid, _zones[GetPVarInt(playerid, "position")][0],_zones[GetPVarInt(playerid, "position")][1],_zones[GetPVarInt(playerid, "position")][2]);
	SetPlayerFacingAngle(playerid, _zones[GetPVarInt(playerid, "position")][3]);

	new str[128];
	format(str, 128, "Пользователь %s был добавлен в раунд администратором.", p_name(playerid));
	SendClientMessageToAll(-1, str);

	ShowPlayerDialog(playerid, 3, DIALOG_STYLE_LIST, "Choose car", "Alpha\nBanshee\nBlista Compact\nBuffalo\nBullet\nCheetah\nTurismo\nPhoenix\nSuper GT\nZR-350", "Choose", "");
}

/*public OnPlayerClickPlayer(playerid, clickedplayerid, source){
	if(!roundEnabled) return true;
	if(!GetPVarInt(clickedplayerid, "_inRound")) return true;
	if(GetPVarInt(playerid, "_inRound")) return true;
	if(playerid == clickedplayerid) return true;
	TogglePlayerSpectating(playerid, 1);
	PlayerSpectatePlayer(playerid, clickedplayerid);
	SetPlayerInterior(playerid,GetPlayerInterior(clickedplayerid));
	return true;
}*/
