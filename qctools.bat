:<<"::CMDLITERAL"
@echo off
setlocal enableextensions enabledelayedexpansion

set ARGS=%*
set QUIET=^> nul
set basedir=%~dp0
set basedir=%basedir:~0,-1%
set PyQt_script=%~dpn0.py

for %%a in (" " "/r ^"%basedir%^"") do ^
for /f "tokens=*" %%p in (where %%~a python.exe 2^> nul) do ^
if exist "%%~p" set python=%%~p

if exist "%basedir%\data\cecho.exe"   (set cecho=%basedir%\data\cecho.exe)
if exist "%basedir%\data\repl.cmd"    (set repl=%basedir%\data\repl.cmd)
if exist "%basedir%\data\emmcdl.exe"  (set downloadbinary=%basedir%\data\emmcdl.exe) ^
else (goto :no_emmcdl)

for /f %%c in ('copy /z "%~f0" nul') do set CR=%%c

if not defined ARGS (
	if exist "%PyQt_script%" (
		if /i "!python!"=="" || (
			echo Requirements:  python
			endlocal & goto :eof
		)
		call "!python!" -m pip list 2>&1 | findstr /r /c:"PyQt5.\s" > nul || (
			echo Requirements:  PyQt5
			endlocal & goto :eof
		)
		call "!python!" "%PyQt_script%"
		endlocal & goto :eof
	)
)

for %%i in (%ARGS:^== %) do (
	if "%%i"=="--list-available"  goto :device_list
	if "%%i"=="--version"         goto :credits
	for %%h in (--help -h) do     if "%%i"=="%%h"  goto :usage
	for %%m in (--method -M) do   if "%%i"=="%%m"  set METHOD_ARGS=1
	for %%v in (--verbose -v) do  if "%%i"=="%%v"  set QUIET=

	for %%l in (
		a33_cph2137  a53_cph2127  a53s_cph2139  a73_cph2099  a74_cph2219
		a95_cph2365  f17_cph2095  f19_cph2219  reno4_cph2113  reno5_cph2159
		reno6_cph2235  7i_rmx2103  c15_rmx2195  c17_rmx2101  8pro_rmx3091
		vivo_y91  vivo_y93  vivo_y95  vivo_v9  vivo_v9yth  vivo_v11pro
		mi8ee_ursa  mi8se_sirius  mi8ud_equuleus  mia2_jasmine mia2lite_daisy
		mimax2_chiron  mimax3_nitrogen  mimix_lithium  mimix2s_polaris
		mimix3_perseus  minote2_scorpio  minote3_jason  mipad4_clover
		pocof1_beryllium  redmi6pro_sakura  redmi7_onclite  redminote5_whyred
		note5pro_whyred  redminote5a_ugglite  sm_a015f  sm_a025f  sm_a115a
		sm_a115f  sm_a115u  sm_a705f  sm_j415f  sm_j610f  sm_m025f  sm_m115f
	) do if "%%i"=="%%l"   set DEVICE=%%l

	if "%%i"=="userdata"   set selected=userdata
	if "%%i"=="frp"        set selected=frp
	if "%%i"=="efs"        set selected=efs
	if "%%i"=="misc"       set selected=misc
	if "%%i"=="micloud"    set selected=micloud
)

if defined DEVICE    call :%DEVICE%
if defined selected  call :choice_%selected%

if not defined METHOD_ARGS  goto :no_method
if not defined METHOD       goto :no_options
if not defined NAME         goto :no_device

call :caption
call :execution
endlocal
goto :eof


:: ######################################################################################################### ::
:: ################################################ CHOICES ################################################ ::
:: ######################################################################################################### ::

:choice_userdata
set METHOD=userdata
set METHOD_FULL=Factory Reset
set firehose=%basedir%\data\loader\%SHORT_BRAND%\%firehosefile%
goto :eof

:choice_frp
set METHOD=frp
set METHOD_FULL=Erase FRP
set firehose=%basedir%\data\loader\%SHORT_BRAND%\%firehosefile%
goto :eof

:choice_efs
set METHOD=efs
set METHOD_FULL=Erase EFS IMEI
set firehose=%basedir%\data\loader\%SHORT_BRAND%\%firehosefile%
goto :eof

:choice_misc
set METHOD=misc
set METHOD_FULL=Safe format data
set firehose=%basedir%\data\loader\%SHORT_BRAND%\%firehosefile%
goto :eof

:choice_micloud
if not "%SHORT_BRAND%"=="xiaomi" (
	echo This method only allowed for Xiaomi brands.
	goto :eof
)
set METHOD=micloud
set METHOD_FULL=Erase MiCloud
set firehose=%basedir%\data\loader\%SHORT_BRAND%\%firehosefile%
goto :eof


:: ######################################################################################################### ::
:: ############################################# MAIN EXECUTION ############################################ ::
:: ######################################################################################################### ::

:execution
for /f "tokens=2*" %%a in ('reg.exe query HKLM\HARDWARE\DEVICEMAP\SERIALCOMM /v \Device\*QCUSB* 2^> nul') do ^
if "%%~b"=="" (goto :no_port) else (set COMPORT=%%~b)

call :get_partition
set "current_time=%DATE:~0,2%_%DATE:~3,2%_%DATE:~6,4%__%TIME:~0,2%_%TIME:~3,2%_%TIME:~6,2%"

set "firehose=%basedir%\data\loader\%SHORT_BRAND%\%firehosefile%"
set "backup_config=%basedir%\data\backup\%current_time%_config.bin"
set "backup_efs_fsg=%basedir%\data\backup\%current_time%_fsg"
set "backup_efs_modemst1=%basedir%\data\backup\%current_time%_modemst1.bin"
set "backup_efs_modemst2=%basedir%\data\backup\%current_time%_modemst2.bin"
set "backup_misc=%basedir%\data\backup\%current_time%_misc.img"
set "backup_persist=%basedir%\data\backup\%current_time%_persist.img"
set "backup_persistbak=%basedir%\data\backup\%current_time%_persistbak.img"
set "backup_persistent=%basedir%\data\backup\%current_time%_persistent.img"

if /i "%METHOD%"=="userdata" (call :process_userdata) else ^
if /i "%METHOD%"=="frp"      (
for %%a in (oppo realme vivo) do (if "%SHORT_BRAND%"=="%%a" TMPVAR=1)
if !TMPVAR!==1 (call :process_frp) else (call :process_config)
) else ^
if /i "%METHOD%"=="efs"      (call :process_efs) else ^
if /i "%METHOD%"=="misc"     (call :process_misc) else ^
if /i "%METHOD%"=="micloud"  (call :process_micloud_xiaomi)

if %ERROR_OPT% EQU 1 (pause & goto :eof)
call :reboot_device
goto :eof

:caption
cls
echo.
echo Selected Model:    %NAME%
echo Selected Brand:    %BRAND%
echo Operation:         %METHOD_FULL%
timeout /nobreak /t 10 > nul
goto :eof

:get_partition
set /p "=[ * ]   Configuring device . . .!_CR!" < nul
call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -gpt -memoryname %type% > "%temp%\partition"
timeout /nobreak /t 1 > nul
"%cecho%" [ {0A}OK{#} ]  Configuring device . . .
goto :eof

:process_userdata
for /f "delims= " %%e in ('type "%temp%\partition" ^| find "userdata"') do (
	set "line=%%e"
	set "line=!line:*userdata =!"
	set /a "result_userdata=!line:~1!" 2> nul
)
if "%result_userdata%" == "1" (
	for /f "tokens=7 " %%f in ('findstr /i "userdata" "%temp%\partition"') do echo Partition userdata sector:   %%f
	timeout /nobreak /t 1 > nul
	set /p "=[ * ]   Erasing userdata . . .!_CR!" < nul
	call "%downloadbinary%" -p "%COMPORT%" -f "%firehose%" -e userdata -memoryname "%type%" %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing userdata . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
goto :eof

:process_frp
for /f "delims= " %%c in ('type "%temp%\partition" ^| find "frp"') do (
	set "line=%%c"
	set "line=!line:*frp =!"
	set /a "result_frp=!line:~1!" 2> nul
)
if "%result_frp%" == "1" (
	for /f "tokens=7 " %%d in ('findstr /i "frp" "%temp%\partition"') do echo Partition FRP sector:   %%d
	timeout /nobreak /t 1 > nul
	set /p "=[ * ]   Erasing FRP . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e frp -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing FRP . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
goto :eof

:process_misc
for /f "delims= " %%e in ('type "%temp%\partition" ^| find "misc"') do (
	set "line=%%e"
	set "line=!line:*misc =!"
	set /a "result_misc=!line:~1!" 2> nul
)
if "%result_misc%" == "1" (
	for /f "tokens=7 " %%f in ('findstr /i "misc" "%temp%\partition"') do (
		echo.Partition misc sector:   %%f
		type "%basedir%\data\xml\patch.xml" | "%repl%" "(start_sector=\q).*?(\q.*>)" "$1%%f$2" xi > "%temp%\patch.xml"
	)
	timeout /nobreak /t 2 > nul
	set /p "=[ * ]   Backing up misc . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d misc "%backup_misc%" -memoryname %type% %QUIET%
	"%cecho%" [ OK ]  Backing up misc . . .
	set /p "=[ * ]   Erasing userdata . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -x "%temp%\patch.xml" -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing userdata . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
goto :eof

:process_config
if /i "%SHORT_BRAND%"=="samsung" (set TMPVAR=persistent) else (set TMPVAR=config)
for /f "delims= " %%a in ('type "%temp%\partition" ^| find "%TMPVAR%"') do (
	set "line=%%a"
	set "line=!line:*%TMPVAR% =!"
	set /a "result_%TMPVAR%=!line:~1!" 2> nul
)
if "%result_%TMPVAR%%" == "1" (
	for /f "tokens=7 skip=1 " %%b in ('findstr /i "%TMPVAR%" "%temp%\partition"') do echo Partition %TMPVAR% sector:   %%b
	timeout /nobreak /t 1 > nul
	set /p "=[ * ]   Backing up %TMPVAR% . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d %TMPVAR% "%backup_config%" -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Backing up %TMPVAR% . . .
	set /p "=[ * ]   Erasing FRP . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e %TMPVAR% -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing FRP . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
goto :eof

:process_micloud_xiaomi
for /f "delims= " %%c in ('type "%temp%\partition" ^| find "persist"') do (
	set "line=%%c"
	set "line=!line:*persist =!"
	set /a "result_persist=!line:~1!" 2> nul
)
if "%result_persist%" == "1" (
	for /f "tokens=7 " %%d in ('findstr /i "persist" "%temp%\partition"') do echo Partition persist sector:   %%d
	%sleep% 1
	set /p "=[ * ]   Backing up persist . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d persist "%backup_persist%" -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Backing up persist . . .
	set /p "=[ * ]   Backing up persistbak . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d persistbak "%backup_persistbak%" -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Backing up persistbak . . .
	set /p "=[ * ]   Erasing MiCloud . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e persist -memoryname %type% %QUIET%
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e persistbak -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing MiCloud . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
goto :eof

:process_efs
for /f "delims= " %%c in ('type "%temp%\partition" ^| find "fsg"') do (
	set "line=%%c"
	set "line=!line:*fsg =!"
	set /a "result_fsg=!line:~1!" 2>nul
)
if "%result_frp%" == "1" (
	for /f "tokens=7 " %%d in ('findstr /i "fsg" "%temp%\partition"') do echo Partition EFS sector:   %%d
	%sleep% 1
	set /p "=[ * ]   Backing up EFS IMEI . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d fsg "%backup_efs_fsg%" -memoryname %type% %QUIET%
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d modemst1 "%backup_efs_modemst1%" -memoryname %type% %QUIET%
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d modemst2 "%backup_efs_modemst2%" -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Backing-up EFS IMEI . . .
	set /p "=[ * ]   Erasing EFS IMEI . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e fsg -memoryname %type% %QUIET%
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e modemst1 -memoryname %type% %QUIET%
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e modemst2 -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing EFS IMEI . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
goto :eof

:reboot_device
set /p "=[ * ]   Rebooting device . . .!_CR!" < nul
timeout /nobreak /t 10 > nul
call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -x "%basedir%\data\xml\boot.xml" -memoryname %type% %QUIET%
"%cecho%" [ {0A}OK{#} ]  Rebooting device . . .
pause
goto :eof


:: ######################################################################################################### ::
:: ###################################### DEVICE LIST SET VARIABLE ######################################### ::
:: ######################################################################################################### ::

:: ############################################# START OPPO ################################################ ::

:a33_cph2137
set NAME=Oppo A33 (CPH-2137^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a33_cph2137
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=emmc
goto :eof

:a53_cph2127
set NAME=Oppo A53 (CPH-2127^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a53_cph2127
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:a53s_cph2139
set NAME=Oppo A53s (CPH-2139^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a53s_cph2139
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=emmc
goto :eof

:a73_cph2099
set NAME=Oppo A73 (CPH-2099^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a73_cph2099
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:a74_cph2219
set NAME=Oppo A74 (CPH-2219^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a74_cph2219
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:a95_cph2365
set NAME=Oppo A95 (CPH-2365^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a95_cph2365
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:f17_cph2095
set NAME=Oppo F17 (CPH-2095^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=f17_cph2095
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:f19_cph2219
set NAME=Oppo F19 (CPH-2219^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=f19_cph2219
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:reno4_cph2113
set NAME=Oppo Reno4 (CPH-2113^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno4_cph2113
set firehosefile=prog_firehose_ddr_oppo_v2.mbn
set type=ufs
goto :eof

:reno5_cph2159
set NAME=Oppo Reno5 (CPH-2159^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno5_cph2159
set firehosefile=prog_firehose_ddr_oppo_v2.mbn
set type=ufs
goto :eof

:reno6_cph2235
set NAME=Oppo Reno6 (CPH-2235^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno6_cph2235
set firehosefile=prog_firehose_ddr_oppo_v2.mbn
set type=ufs
goto :eof


:: ############################################## END OPPO ################################################# ::
:: ############################################ START REALME ############################################### ::


:7i_rmx2103
set NAME=Realme 7i (RMX-2103^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=7i_rmx2103
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:c15_rmx2195
set NAME=Realme C15 (RMX-2195^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=c15_rmx2195
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=emmc
goto :eof

:c17_rmx2101
set NAME=Realme C17 (RMX-2101^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=c17_rmx2101
set firehosefile=prog_firehose_ddr_oppo_v1.mbn
set type=ufs
goto :eof

:8pro_rmx3091
set NAME=Realme 8 Pro (RMX-3091^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=8pro_rmx3091
set firehosefile=prog_firehose_ddr_oppo_v2.mbn
set type=ufs
goto :eof


:: ############################################# END REALME ################################################ ::
:: ############################################# START VIVO ################################################ ::


:vivo_y91
set NAME=Vivo Y91
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y91
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
goto :eof

:vivo_y93
set NAME=Vivo Y93
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y93
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
goto :eof

:vivo_y95
set NAME=Vivo Y95
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y95
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
goto :eof

:vivo_v9
set NAME=Vivo V9
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v9
set firehosefile=prog_emmc_firehose_8953_ddr_vivo_v9.mbn
set type=emmc
goto :eof

:vivo_v9yth
set NAME=Vivo V9 Youth
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v9yth
set firehosefile=prog_emmc_firehose_8953_ddr_vivo_v9_youth.mbn
set type=emmc
goto :eof

:vivo_v11pro
set NAME=Vivo V11 Pro
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v11pro
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
goto :eof


:: ############################################## END VIVO ################################################# ::
:: ############################################# START XIAOMI ############################################## ::


:mi8ee_ursa
set NAME=Xiaomi Mi 8 EE (Ursa^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=ursa
set firehosefile=prog_ufs_firehose_sdm845_ddr_mi8ee_ursa_sig_rb1.elf
set type=ufs
goto :eof

:mi8se_sirius
set NAME=Xiaomi Mi 8 SE (Sirius^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=sirius
set firehosefile=prog_emmc_firehose_Sdm670_ddr_xiaomi_mi8se_sirius_sig_rb1.mbn
set type=emmc
goto :eof

:mi8ud_equuleus
set NAME=Xiaomi Mi 8 UD (Equuleus^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=equuleus
set firehosefile=prog_ufs_firehose_sdm845_ddr_mi8ud_equuleus_sig_rb1.elf
set type=ufs
goto :eof

:mia2_jasmine
set NAME=Xiaomi Mi A2 (Jasmine^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=jasmine
set firehosefile=prog_emmc_firehose_Sdm660_ddr_mia2_jasmine_rb2.elf
set type=emmc
goto :eof

:mia2lite_daisy
set NAME=Xiaomi Mi A2 Lite (Daisy^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=daisy
set firehosefile=prog_emmc_firehose_8953_ddr_mia2lite_daisy_rb1.mbn
set type=emmc
goto :eof

:mimax2_chiron
set NAME=Xiaomi Mi Max 2 (Chiron^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=chiron
set firehosefile=prog_ufs_firehose_8998_ddr_xiaomi_mimax2_chiron_rb1.elf
set type=ufs
goto :eof

:mimax3_nitrogen
set NAME=Xiaomi Mi Max 3 (Nitrogen^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=nitrogen
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi1_mimax3_nitrogen_rb4.elf
set type=emmc
goto :eof

:mimix_lithium
set NAME=Xiaomi Mi Mix (Lithium^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=lithium
set firehosefile=prog_ufs_firehose_8996_ddr_xiaomi_mimix_lithium_rb1.elf
set type=ufs
goto :eof

:mimix2s_polaris
set NAME=Xiaomi Mi Mix 2s (Polaris^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=polaris
set firehosefile=prog_ufs_firehose_Sdm845_ddr_xiaomi_sig_mimix2s_polaris_rb1.elf
set type=ufs
goto :eof

:mimix3_perseus
set NAME=Xiaomi Mi Mix 3 (Perseus^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=perseus
set firehosefile=prog_ufs_firehose_sdm845_ddr_sig_mimix3_perseus_rb2.elf
set type=ufs
goto :eof

:minote2_scorpio
set NAME=Xiaomi Mi Note 2 (Jason^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=scorpio
set firehosefile=prog_ufs_firehose_8996_ddr_xiaomi_minote2_scorpio_rb1.elf
set type=ufs
goto :eof

:minote3_jason
set NAME=Xiaomi Mi Note 3 (Jason^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=jason
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_minote3_jason_rb1.elf
set type=emmc
goto :eof

:mipad4_clover
set NAME=Xiaomi Mi Pad 4 (Clover^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=clover
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_mipad4_clover_s_rb4.elf
set type=emmc
goto :eof

:pocof1_beryllium
set NAME=Xiaomi Pocophone F1 (Beryllium^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=beryllium
set firehosefile=prog_ufs_firehose_sdm845_ddr_pocof1_beryllium_sig_rb1.mbn
set type=ufs
goto :eof

:redmi6pro_sakura
set NAME=Xiaomi Redmi 6 Pro (Sakura^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=sakura
set firehosefile=prog_emmc_firehose_8953_ddr_xiaomi_6pro_sakura_rb1.mbn
set type=emmc
goto :eof

:redmi7_onclite
set NAME=Xiaomi Redmi 7 (Onclite^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=onclite
set firehosefile=prog_emmc_firehose_8953_ddr_redmi7.mbn
set type=emmc
goto :eof

:redminote5_whyred
set NAME=Xiaomi Redmi Note 5 (Whyred^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=whyred
set firehosefile=prog_emmc_firehose_Sdm660_ddr_note5_whyred_s_rb4.elf
set type=emmc
goto :eof

:note5pro_whyred
set NAME=Xiaomi Redmi Note 5 Pro (Whyred^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=whyred
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_note5pro_whyred_s_rb4.elf
set type=emmc
goto :eof

:redminote5a_ugglite
set NAME=Xiaomi Redmi Note 5A (Ugglite^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=ugglite
set firehosefile=prog_emmc_firehose_8917_ddr_note5a_ugglite.mbn
set type=emmc
goto :eof


:: ############################################# END XIAOMI ################################################ ::
:: ############################################ START SAMSUNG ############################################## ::


:sm_a015f
set NAME=Samsung Galaxy A01 (SM-A015F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a015f
set firehosefile=prog_emmc_firehose_8937_A015F.mbn
set type=emmc
goto :eof

:sm_a025f
set NAME=Samsung Galaxy A02s (SM-A025F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a025f
set firehosefile=prog_emmc_firehose_8937_A025F.mbn
set type=emmc
goto :eof

:sm_a115a
set NAME=Samsung Galaxy A11 (SM-A115A^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a115a
set firehosefile=prog_emmc_firehose_8953_A115A.mbn
set type=emmc
goto :eof

:sm_a115f
set NAME=Samsung Galaxy A11 (SM-A115F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a115f
set firehosefile=prog_emmc_firehose_8953_A115F.mbn
set type=emmc
goto :eof

:sm_a115u
set NAME=Samsung Galaxy A11 (SM-A115U^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a115u1
set firehosefile=prog_emmc_firehose_8953_A115U.mbn
set type=emmc
goto :eof

:sm_a705f
set NAME=Samsung Galaxy A70 (SM-A705F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a705f
set firehosefile=prog_ufs_firehose_ddr_A705F.mbn
set type=ufs
goto :eof

:sm_j415f
set NAME=Samsung Galaxy J4 Plus (SM-J415F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_j415f
set firehosefile=prog_ufs_firehose_8917_J415F.mbn
set type=ufs
goto :eof

:sm_j610f"
set NAME=Samsung Galaxy J6 Plus (SM-J610F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_j610f
set firehosefile=prog_ufs_firehose_8917_J610F.mbn
set type=ufs
goto :eof

:sm_m025f
set NAME=Samsung Galaxy M02s (SM-M02s^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_m025f
set firehosefile=prog_emmc_firehose_8953_M025F.mbn
set type=emmc
goto :eof

:sm_m115f
set NAME=Samsung Galaxy M11 (SM-M115F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_m115f
set firehosefile=prog_emmc_firehose_8953_M115F.mbn
set type=emmc
goto :eof


:: ############################################# END SAMSUNG ############################################### ::

:: ######################################################################################################### ::
:: ############################################### MESSAGES ################################################ ::
:: ######################################################################################################### ::

:usage
echo USAGE:  %~n0 ^<device^> [OPTION]...
echo.
echo   -h, --help      show help
echo   -M, --method    choose what do you execute
echo   -v, --verbose   explain what is being done
echo       --version   show script file version and credits
echo.
echo To see device list, type  %~n0 --list-available
endlocal
goto :eof

:credits
echo Qualcomm Flasher Tool for Linux
echo Unlock and flash the Android phone devices.
echo Version report:  1.0
echo.
echo This script created by Faizal Hamzah [The Firefox Flasher].
echo Licensed under the MIT License.
echo.
echo Credits:
echo    nijel8           Developer of emmcdl binary
echo    bjoerkerler      Qualcomm Firehose Attacker source code
echo    Hari Sulteng     Qualcomm GSM Sulteng
echo    Hadi Khoirudin   Qualcomm Tools, a simple unlocker
endlocal
goto :eof

:device_list
echo Devices list available in this tools:
echo.
echo   a33_cph2137            Oppo A33
echo   a53_cph2127            Oppo A53
echo   a53s_cph2139           Oppo A53S
echo   a73_cph2099            Oppo A73
echo   a74_cph2219            Oppo A74
echo   a95_cph2365            Oppo A95
echo   f17_cph2095            Oppo F17
echo   f19_cph2219            Oppo F19
echo   reno4_cph2113          Oppo Reno4
echo   reno5_cph2159          Oppo Reno5
echo   reno6_cph2235          Oppo Reno6
echo.
echo   7i_rmx2103             Realme 7i
echo   c15_rmx2195            Realme C15
echo   c17_rmx2101            Realme C17
echo   8pro_rmx3091           Realme 8 Pro
echo.
echo   vivo_y91               Vivo Y91
echo   vivo_y93               Vivo Y93
echo   vivo_y95               Vivo Y95
echo   vivo_v9                Vivo V9
echo   vivo_v9yth             Vivo V9 Youth
echo   vivo_v11pro            Vivo V11 Pro
echo.
echo   mi8ee_ursa             Xiaomi Mi 8 EE
echo   mi8se_sirius           Xiaomi Mi 8 SE
echo   mi8ud_equuleus         Xiaomi Mi 8 UD
echo   mia2_jasmine           Xiaomi Mi A2
echo   mia2lite_daisy         Xiaomi Mi A2 Lite
echo   mimax2_chiron          Xiaomi Mi Max 2
echo   mimax3_nitrogen        Xiaomi Mi Max 3
echo   mimix_lithium          Xiaomi Mi Mix
echo   mimix2s_polaris        Xiaomi Mi Mix 2s
echo   mimix3_perseus         Xiaomi Mi Mix 3
echo   minote2_scorpio        Xiaomi Mi Note 2
echo   minote3_jason          Xiaomi Mi Note 3
echo   mipad4_clover          Xiaomi Mi Pad 4
echo   pocof1_beryllium       Xiaomi Pocophone F1
echo   redmi6pro_sakura       Xiaomi Redmi 6 Pro
echo   redmi7_onclite         Xiaomi Redmi 7
echo   redminote5_whyred      Xiaomi Redmi Note 5
echo   note5pro_whyred        Xiaomi Redmi Note 5 Pro
echo   redminote5a_ugglite    Xiaomi Redmi Note 5a
echo.
echo   sm_a015f               Samsung Galaxy A01
echo   sm_a025f               Samsung Galaxy A02s
echo   sm_a115a               Samsung Galaxy A11
echo   sm_a115f               Samsung Galaxy A11
echo   sm_a115u               Samsung Galaxy A11
echo   sm_a705f               Samsung Galaxy A70
echo   sm_j415f               Samsung Galaxy J4 Plus
echo   sm_j610f               Samsung Galaxy J6 Plus
echo   sm_m025f               Samsung Galaxy M02s
echo   sm_m115f               Samsung Galaxy M11
endlocal
goto :eof

:no_emmcdl
echo emmcdl is not found.
endlocal
goto :eof

:no_method
echo Invalid switch parameter.
endlocal
goto :eof

:no_options
echo No option inserted.
endlocal
goto :eof

:no_device
echo Device is not availabled.
endlocal
goto :eof

:no_port
echo.& echo Error:  Qualcomm HS-USB port not detected.
echo.& pause
endlocal
goto :eof
::CMDLITERAL


ARGS="$*"
QUIET=">/dev/null"
TMPDIR="/var/tmp/$(basename "$0")"
basedir="$(dirname "$(readlink -f "$0")")"
PyQt_script="$basedir/$(basename "$0" | sed s/\..bat$//g).py"
downloadbinary="$basedir/data/emmcdl"
if [ ! -d "$TMPDIR" ]; then mkdir -p "$TMPDIR"; fi
if [ ! -x "$downloadbinary" ] ; then
	for x in "git" "aclocal" "autoconf" "automake" "make"; do
	command -v $x >/dev/null 2>&1 || {
		echo "$x is not found."
		exit 1
	}
	done

	[ -d "$basedir/data/sources/emmcdl" ] || \
	git clone https://github.com/nijel8/emmcdl.git "$basedir/data/sources/emmcdl" >/dev/null 2>&1
	[ -d "$basedir/data/sources/emmcdl" ] && cd "$basedir/data/sources/emmcdl"
	( aclocal && autoconf && automake --add-missing ) >/dev/null 2>&1
	( ./configure --quiet && make --quiet ) >/dev/null 2>&1
	mv emmcdl "$downloadbinary" >/dev/null 2>&1 || {
		echo "emmcdl is not found."
		exit 1
	}
fi
cd "$basedir"

# #########################################################################################################
# ############################################# MAIN EXECUTION ############################################
# #########################################################################################################

current_time() {
	date +%m_%d_%Y__%H_%M_%S
}

execution() {
	lsusb 2>&1 | grep "Qualcomm.*USB" >/dev/null || {
		echo
		echo "Error:  Qualcomm HS-USB port not detected."
		echo
		exit 1
	}

	get_partition

	firehose="$basedir/data/loader/$SHORT_BRAND/$firehosefile"
	backup_config="$basedir/data/backup/$(current_time)_config.bin"
	backup_efs_fsg="$basedir/data/backup/$(current_time)_fsg"
	backup_efs_modemst1="$basedir/data/backup/$(current_time)_modemst1.bin"
	backup_efs_modemst2="$basedir/data/backup/$(current_time)_modemst2.bin"
	backup_misc="$basedir/data/backup/$(current_time)_misc.img"
	backup_persist="$basedir/data/backup/$(current_time)_persist.img"
	backup_persistbak="$basedir/data/backup/$(current_time)_persistbak.img"
	backup_persistent="$basedir/data/backup/$(current_time)_persistent.img"

	case $METHOD in
		"userdata" )
		  process_userdata
		  ;;
		"frp" )
		  for bbk in oppo realme vivo; do
		  [ "$SHORT_BRAND" = "$bbk" ] && TMPVAR=1
		  done
		  [ $ -eq 1 ] && \
		  process_frp || \
		  process_config
		  ;;
		"efs" )
		  process_efs
		  ;;
		"misc" )
		  process_misc
		  ;;
		"micloud" )
		  process_micloud_xiaomi
		  ;;
	esac
	reboot_device
}

caption() {
	clear
	echo
	echo "Selected Model:    $NAME"
	echo "Selected Brand:    $BRAND"
	echo "Operation:         $METHOD_FULL"
	sleep 10
}

get_partition() {
	echo $'[ * ]   Configuring device . . . \r'
	eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -gpt -memoryname $type > "$TMPDIR/partition"
	sleep 1
	echo $'[ \e[1;32mOK\e[0m ]  Configuring device . . . '
}

process_userdata() {
	for f in $(cat $TMPDIR/partition | tr -d ' '); do
		[ "${f//*userdata /}" == "1" ] && {
			echo "Partition userdata sector:   $(grep "userdata" "$TMPDIR/partition" | cut -f7)"
			sleep 1
			echo $'[ * ]   Erasing userdata . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e userdata -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Erasing userdata . . . '
		} || {
			echo $'\e[1;31mERROR\e[0m:  '$type' damaged.'
			pause; exit 1
		}
	done
}

process_frp() {
	for f in $(cat $TMPDIR/partition | tr -d ' '); do
		[ "${f//*frp /}" == "1" ] && {
			echo "Partition FRP sector:   $(grep "frp" "$TMPDIR/partition" | cut -f7)"
			sleep 1
			echo $'[ * ]   Erasing FRP . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e frp -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Erasing FRP . . . '
		} || {
			echo $'\e[1;31mERROR\e[0m:  '$type' damaged.'
			pause; exit 1
		}
	done
}

process_misc() {
	for f in $(cat $TMPDIR/partition | tr -d ' '); do
		[ "${f//*misc /}" == "1" ] && {
		  for sector in $(grep "misc" "$TMPDIR/partition" | cut -f7); do
			  echo "Partition misc sector:   $sector"
			  cat "$basedir/data/xml/patch.xml" | \
			  sed "s/(start_sector=\q).*?(\q.*>)/$1${sector}$2/" > "$TMPDIR/patch.xml"
		  done
			sleep 2
			echo $'[ * ]   Backing up misc . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d misc "$backup_misc" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up misc . . . '
			echo $'[ * ]   Erasing userdata . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -x "$TMPDIR/patch.xml" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Erasing userdata . . . '
		} || {
			echo $'\e[1;31mERROR\e[0m:  '$type' damaged.'
			pause; exit 1
		}
	done
}

process_config() {
	[ "$SHORT_BRAND" = "samsung" ] && \
	TMPVAR="persistent" || TMPVAR="config"
	for f in $(cat $TMPDIR/partition | grep "$TMPVAR" | tr -d ' '); do
		[ "${f//*$TMPVAR /}" == "1" ] && {
			echo "Partition $TMPVAR sector:   $(grep "$TMPVAR" "$TMPDIR/partition" | cut -f7)"
			sleep 1
			echo $'[ * ]   Backing up $TMPVAR . . . \r'
			[ "$SHORT_BRAND" = "samsung" ] && \
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d $TMPVAR "$backup_persistent" -memoryname $type $QUIET || \
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d $TMPVAR "$backup_config" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up $TMPVAR . . . '
			echo $'[ * ]   Erasing FRP . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e config -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Erasing FRP . . . '
		} || {
			echo $'\e[1;31mERROR\e[0m:  '$type' damaged.'
			pause; exit 1
		}
	done
}

process_micloud_xiaomi() {
	for f in $(cat $TMPDIR/partition | grep "persist" | tr -d ' '); do
		[ "${f//*persist /}" == "1" ] && {
			echo "Partition persist sector:   $(grep "persist" "$TMPDIR/partition" | cut -f7)"
			sleep 1
			echo $'[ * ]   Backing up persist . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d persist "$backup_persist" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up persist . . . '
			echo $'[ * ]   Backing up persistbak . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d persistbak "$backup_persistbak" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up persistbak . . . \r'
			echo $'[ * ]   Erasing MiCloud . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e persist -memoryname $type $QUIET
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e persistbak -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Erasing MiCloud . . . '
		} || {
			echo $'\e[1;31mERROR\e[0m:  '$type' damaged.'
			pause; exit 1
		}
	done
}

process_efs() {
	for f in $(cat $TMPDIR/partition | grep "fsg" | tr -d ' '); do
		[ "${f//*fsg /}" == "1" ] && {
			echo "Partition EFS sector:   $(grep "fsg" "$TMPDIR/partition" | cut -f7)"
			sleep 1
			echo $'[ * ]   Backing up EFS IMEI . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d fsg "$backup_efs_fsg" -memoryname $type $QUIET
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d modemst1 "$backup_efs_modemst1" -memoryname $type $QUIET
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d modemst2 "$backup_efs_modemst2" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up EFS IMEI . . . '
			echo $'[ * ]   Erasing EFS IMEI . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e fsg -memoryname $type $QUIET
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e modemst1 -memoryname $type $QUIET
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -e modemst2 -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Erasing EFS IMEI . . . '
		} || {
			echo $'\e[1;31mERROR\e[0m:  '$type' damaged.'
			pause; exit 1
		}
	done
}

reboot_device() {
	echo $'[ * ]   Rebooting device . . . \r'
	eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -x "$basedir/data/xml/boot.xml" -memoryname $type $QUIET
	echo $'[ \e[1;32mOK\e[0m ]  Rebooting device . . . '
	pause
}

pause() {
	echo -n "Press any key to continue . . . "
	read -srn1; echo
}

show_usage() {
	printf "%s" "\
USAGE:  $0 <device> [OPTION]...

    -h, --help       show help
    -M, --method     choose what do you execute
    -v, --verbose    explain what is being done
        --version    show script file version and credits

To see device list, type  $0 --list-available
"
}

show_credits() {
	printf "%s" "\
Qualcomm Flasher Tool for Linux
Unlock and flash the Android phone devices.
Version report:  1.0

This script created by Faizal Hamzah [The Firefox Flasher].
Licensed under the MIT License.

Credits:
    nijel8            Developer of emmcdl binary
    bjoerkerler       Qualcomm Firehose Attacker source code
    Hari Sulteng      Qualcomm GSM Sulteng
    Hadi Khoirudin    Qualcomm Tools, a simple unlocker
"
}

show_device_list() {
	printf "%s" "\
Devices list available in this tools:

    a33_cph2137            Oppo A33
    a53_cph2127            Oppo A53
    a53s_cph2139           Oppo A53S
    a73_cph2099            Oppo A73
    a74_cph2219            Oppo A74
    a95_cph2365            Oppo A95
    f17_cph2095            Oppo F17
    f19_cph2219            Oppo F19
    reno4_cph2113          Oppo Reno4
    reno5_cph2159          Oppo Reno5
    reno6_cph2235          Oppo Reno6

    7i_rmx2103             Realme 7i
    c15_rmx2195            Realme C15
    c17_rmx2101            Realme C17
    8pro_rmx3091           Realme 8 Pro

    vivo_y91               Vivo Y91
    vivo_y93               Vivo Y93
    vivo_y95               Vivo Y95
    vivo_v9                Vivo V9
    vivo_v9yth             Vivo V9 Youth
    vivo_v11pro            Vivo V11 Pro

    mi8ee_ursa             Xiaomi Mi 8 EE
    mi8se_sirius           Xiaomi Mi 8 SE
    mi8ud_equuleus         Xiaomi Mi 8 UD
    mia2_jasmine           Xiaomi Mi A2
    mia2lite_daisy         Xiaomi Mi A2 Lite
    mimax2_chiron          Xiaomi Mi Max 2
    mimax3_nitrogen        Xiaomi Mi Max 3
    mimix_lithium          Xiaomi Mi Mix
    mimix2s_polaris        Xiaomi Mi Mix 2s
    mimix3_perseus         Xiaomi Mi Mix 3
    minote2_scorpio        Xiaomi Mi Note 2
    minote3_jason          Xiaomi Mi Note 3
    mipad4_clover          Xiaomi Mi Pad 4
    pocof1_beryllium       Xiaomi Pocophone F1
    redmi6pro_sakura       Xiaomi Redmi 6 Pro
    redmi7_onclite         Xiaomi Redmi 7
    redminote5_whyred      Xiaomi Redmi Note 5
    note5pro_whyred        Xiaomi Redmi Note 5 Pro
    redminote5a_ugglite    Xiaomi Redmi Note 5a

    sm_a015f               Samsung Galaxy A01
    sm_a025f               Samsung Galaxy A02s
    sm_a115a               Samsung Galaxy A11
    sm_a115f               Samsung Galaxy A11
    sm_a115u               Samsung Galaxy A11
    sm_a705f               Samsung Galaxy A70
    sm_j415f               Samsung Galaxy J4 Plus
    sm_j610f               Samsung Galaxy J6 Plus
    sm_m025f               Samsung Galaxy M02s
    sm_m115f               Samsung Galaxy M11
"
}

# #########################################################################################################
# ###################################### DEVICE LIST SET VARIABLE #########################################
# #########################################################################################################

for i in $(printf "%s\n" "$ARGS" | sed "s/=/ /g"); do
# ########################################## START OPPO ###################################################

case $i in
	"a33_cph2137" )
	  NAME="Oppo A33 (CPH-2137)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a33_cph2137"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="emmc"
	  ;;
	"a53_cph2127" )
	  NAME="Oppo A53 (CPH-2127)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a53_cph2127"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"a53s_cph2139" )
	  NAME="Oppo A53s (CPH-2139)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a53s_cph2139"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="emmc"
	  ;;
	"a73_cph2099" )
	  NAME="Oppo A73 (CPH-2099)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a73_cph2099"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"a74_cph2219" )
	  NAME="Oppo A74 (CPH-2219)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a74_cph2219"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"a95_cph2365" )
	  NAME="Oppo A95 (CPH-2365)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a95_cph2365"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"f17_cph2095" )
	  NAME="Oppo F17 (CPH-2095)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="f17_cph2095"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"f19_cph2219" )
	  NAME="Oppo F19 (CPH-2219)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="f19_cph2219"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"reno4_cph2113" )
	  NAME="Oppo Reno4 (CPH-2113)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno4_cph2113"
	  firehosefile="prog_firehose_ddr_oppo_v2.mbn"
	  type="ufs"
	  ;;
	"reno5_cph2159" )
	  NAME="Oppo Reno5 (CPH-2159)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno5_cph2159"
	  firehosefile="prog_firehose_ddr_oppo_v2.mbn"
	  type="ufs"
	  ;;
	"reno6_cph2235" )
	  NAME="Oppo Reno6 (CPH-2235)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno6_cph2235"
	  firehosefile="prog_firehose_ddr_oppo_v2.mbn"
	  type="ufs"
	  ;;
esac

# ########################################### END OPPO ####################################################
# ######################################### START REALME ##################################################

case $i in
	"7i_rmx2103" )
	  NAME="Realme 7i (RMX-2103)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="7i_rmx2103"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"c15_rmx2195" )
	  NAME="Realme C15 (RMX-2195)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="c15_rmx2195"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="emmc"
	  ;;
	"c17_rmx2101" )
	  NAME="Realme C17 (RMX-2101)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="c17_rmx2101"
	  firehosefile="prog_firehose_ddr_oppo_v1.mbn"
	  type="ufs"
	  ;;
	"8pro_rmx3091" )
	  NAME="Realme 8 Pro (RMX-3091)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="8pro_rmx3091"
	  firehosefile="prog_firehose_ddr_oppo_v2.mbn"
	  type="ufs"
	  ;;
esac

# ########################################## END REALME ###################################################
# ########################################## START VIVO ###################################################

case $i in
	"vivo_y91" )
	  NAME="Vivo Y91"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y91"
	  firehosefile="prog_emmc_firehose_8937_y91_y93_y95_v11.mbn"
	  type="emmc"
	  ;;
	"vivo_y93" )
	  NAME="Vivo Y93"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y93"
	  firehosefile="prog_emmc_firehose_8937_y91_y93_y95_v11.mbn"
	  type="emmc"
	  ;;
	"vivo_y95" )
	  NAME="Vivo Y95"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y95"
	  firehosefile="prog_emmc_firehose_8937_y91_y93_y95_v11.mbn"
	  type="emmc"
	  ;;
	"vivo_v9" )
	  NAME="Vivo V9"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="v9"
	  firehosefile="prog_emmc_firehose_8953_ddr_vivo_v9.mbn"
	  type="emmc"
	  ;;
	"vivo_v9yth" )
	  NAME="Vivo V9 Youth"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="v9yth"
	  firehosefile="prog_emmc_firehose_8953_ddr_vivo_v9_youth.mbn"
	  type="emmc"
	  ;;
	"vivo_v11pro" )
	  NAME="Vivo V11 Pro"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="v11pro"
	  firehosefile="prog_emmc_firehose_8937_y91_y93_y95_v11.mbn"
	  type="emmc"
	  ;;
esac

# ########################################### END VIVO ####################################################
# ######################################### START XIAOMI ##################################################

case $i in
	"mi8ee_ursa" )
	  NAME="Xiaomi Mi 8 EE (Ursa)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="ursa"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_mi8ee_ursa_sig_rb1.elf"
	  type="ufs"
	  ;;
	"mi8se_sirius" )
	  NAME="Xiaomi Mi 8 SE (Sirius)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="sirius"
	  firehosefile="prog_emmc_firehose_Sdm670_ddr_xiaomi_mi8se_sirius_sig_rb1.mbn"
	  type="emmc"
	  ;;
	"mi8ud_equuleus" )
	  NAME="Xiaomi Mi 8 UD (Equuleus)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="equuleus"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_mi8ud_equuleus_sig_rb1.elf"
	  type="ufs"
	  ;;
	"mia2_jasmine" )
	  NAME="Xiaomi Mi A2 (Jasmine)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="jasmine"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_mia2_jasmine_rb2.elf"
	  type="emmc"
	  ;;
	"mia2lite_daisy" )
	  NAME="Xiaomi Mi A2 Lite (Daisy)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="daisy"
	  firehosefile="prog_emmc_firehose_8953_ddr_mia2lite_daisy_rb1.mbn"
	  type="emmc"
	  ;;
	"mimax2_chiron" )
	  NAME="Xiaomi Mi Max 2 (Chiron)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="chiron"
	  firehosefile="prog_ufs_firehose_8998_ddr_xiaomi_mimax2_chiron_rb1.elf"
	  type="ufs"
	  ;;
	"mimax3_nitrogen" )
	  NAME="Xiaomi Mi Max 3 (Nitrogen)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="nitrogen"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_xiaomi1_mimax3_nitrogen_rb4.elf"
	  type="emmc"
	  ;;
	"mimix_lithium" )
	  NAME="Xiaomi Mi Mix (Lithium)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="lithium"
	  firehosefile="prog_ufs_firehose_8996_ddr_xiaomi_mimix_lithium_rb1.elf"
	  type="ufs"
	  ;;
	"mimix2s_polaris" )
	  NAME="Xiaomi Mi Mix 2s (Polaris)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="polaris"
	  firehosefile="prog_ufs_firehose_Sdm845_ddr_xiaomi_sig_mimix2s_polaris_rb1.elf"
	  type="ufs"
	  ;;
	"mimix3_perseus" )
	  NAME="Xiaomi Mi Mix 3 (Perseus)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="perseus"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_sig_mimix3_perseus_rb2.elf"
	  type="ufs"
	  ;;
	"minote2_scorpio" )
	  NAME="Xiaomi Mi Note 2 (Jason)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="scorpio"
	  firehosefile="prog_ufs_firehose_8996_ddr_xiaomi_minote2_scorpio_rb1.elf"
	  type="ufs"
	  ;;
	"minote3_jason" )
	  NAME="Xiaomi Mi Note 3 (Jason)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="jason"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_xiaomi_minote3_jason_rb1.elf"
	  type="emmc"
	  ;;
	"mipad4_clover" )
	  NAME="Xiaomi Mi Pad 4 (Clover)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="clover"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_xiaomi_mipad4_clover_s_rb4.elf"
	  type="emmc"
	  ;;
	"pocof1_beryllium" )
	  NAME="Xiaomi Pocophone F1 (Beryllium)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="beryllium"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_pocof1_beryllium_sig_rb1.mbn"
	  type="ufs"
	  ;;
	"redmi6pro_sakura" )
	  NAME="Xiaomi Redmi 6 Pro (Sakura)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="sakura"
	  firehosefile="prog_emmc_firehose_8953_ddr_xiaomi_6pro_sakura_rb1.mbn"
	  type="emmc"
	  ;;
	"redmi7_onclite" )
	  NAME="Xiaomi Redmi 7 (Onclite)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="onclite"
	  firehosefile="prog_emmc_firehose_8953_ddr_redmi7_onc_onclite.mbn"
	  type="emmc"
	  ;;
	"redminote5_whyred" )
	  NAME="Xiaomi Redmi Note 5 (Whyred)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="whyred"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_note5_whyred_s_rb4.elf"
	  type="emmc"
	  ;;
	"note5pro_whyred" )
	  NAME="Xiaomi Redmi Note 5 Pro (Whyred)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="whyred"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_xiaomi_note5pro_whyred_s_rb4.elf"
	  type="emmc"
	  ;;
	"redminote5a_ugglite" )
	  NAME="Xiaomi Redmi Note 5A (Ugglite)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="ugglite"
	  firehosefile="prog_emmc_firehose_8917_ddr_note5a_ugglite.mbn"
	  type="emmc"
	  ;;
esac

# ########################################## END XIAOMI ###################################################
# ######################################## START SAMSUNG ##################################################

case $i in
	"sm_a015f" )
	  NAME="Samsung Galaxy A01 (SM-A015F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_a015f"
	  firehosefile="prog_emmc_firehose_8937_A015F.mbn"
	  type="emmc"
	  ;;
	"sm_a025f" )
	  NAME="Samsung Galaxy A02s (SM-A025F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_a025f"
	  firehosefile="prog_emmc_firehose_8937_A025F.mbn"
	  type="emmc"
	  ;;
	"sm_a115a" )
	  NAME="Samsung Galaxy A11 (SM-A115A)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_a115a"
	  firehosefile="prog_emmc_firehose_8953_A115A.mbn"
	  type="emmc"
	  ;;
	"sm_a115f" )
	  NAME="Samsung Galaxy A11 (SM-A115F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_a115f"
	  firehosefile="prog_emmc_firehose_8953_A115F.mbn"
	  type="emmc"
	  ;;
	"sm_a115u" )
	  NAME="Samsung Galaxy A11 (SM-A115U)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_a115u1"
	  firehosefile="prog_emmc_firehose_8953_A115U.mbn"
	  type="emmc"
	  ;;
	"sm_a705f" )
	  NAME="Samsung Galaxy A70 (SM-A705F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_a705f"
	  firehosefile="prog_ufs_firehose_ddr_A705F.mbn"
	  type="ufs"
	  ;;
	"sm_j415f" )
	  NAME="Samsung Galaxy J4 Plus (SM-J415F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_j415f"
	  firehosefile="prog_ufs_firehose_8917_J415F.mbn"
	  type="ufs"
	  ;;
	"sm_j610f" )
	  NAME="Samsung Galaxy J6 Plus (SM-J610F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_j610f"
	  firehosefile="prog_ufs_firehose_8917_J610F.mbn"
	  type="ufs"
	  ;;
	"sm_m025f" )
	  NAME="Samsung Galaxy M02s (SM-M02s)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_m025f"
	  firehosefile="prog_emmc_firehose_8953_M025F.mbn"
	  type="emmc"
	  ;;
	"sm_m115f" )
	  NAME="Samsung Galaxy M11 (SM-M115F)"
	  BRAND="Samsung"
	  SHORT_BRAND="samsung"
	  DEVICE="sm_m115f"
	  firehosefile="prog_emmc_firehose_8953_M115F.mbn"
	  type="emmc"
	  ;;
esac

# ######################################### END SAMSUNG ###################################################

# #########################################################################################################
# ############################################### MESSAGES ################################################
# #########################################################################################################

case $i in
	"--help" | "-h" )
	  show_usage
	  exit
	  ;;
	"--version" )
	  show_credits
	  exit
	  ;;
	"--verbose" | "-v" )
	  unset QUIET
	  ;;
	"--list-available" )
	  show_device_list
	  exit
	  ;;
	"--method" | "-M" )
	  METHOD_ARGS="1"
	  ;;
	"userdata" )
	  METHOD="userdata"
	  METHOD_FULL="Erase userdata"
	  ;;
	"frp" )
	  METHOD="frp"
	  METHOD_FULL="Erase FRP"
	  ;;
	"efs" )
	  METHOD="efs"
	  METHOD_FULL="Erase EFS IMEI"
	  ;;
	"misc" )
	  METHOD="misc"
	  METHOD_FULL="Safe format data"
	  ;;
	"micloud" )
	  [ "$SHORT_BRAND" != "xiaomi" ] && {
		  echo "This method only allowed for Xiaomi brands."
		  exit 1
	  }
	  METHOD="micloud"
	  METHOD_FULL="Erase MiCloud"
	  ;;
esac
done

if [[ -z "$ARGS" ]]; then
	[ -f "$PyQt_script" ] || {
		echo "This is development release. Coming soon:  GUI window."
		exit 1
	}
	command -v python >/dev/null || {
		echo "Requirements:  python"
		exit 1
	}
	python -m pip list 2>&1 | grep "PyQt5.\s" >/dev/null || {
		echo "Requirements:  PyQt5"
		exit 1
	}

	python "$PyQt_script"
	exit
elif [ -z "$METHOD_ARGS" ]; then
	echo "Invalid switch parameter."
	exit 1
elif [ -z "$METHOD" ]; then
	echo "No option inserted."
	exit 1
elif [ -z "$NAME" ]; then
	echo "Device is not availabled."
	exit 1
fi

caption
execution
exit
