:<<cmd
:: begin_batch_script

@echo off

for %%v in (Daytona Cairo Hydra Neptune NT) do ^
ver | find "%%v" > nul && ^
if not errorlevel 1  set OLD_WIN=1

if %OLD_WIN%?==1?  goto det_oldwinnt
if %OLD_WIN%?==0?  setlocal enableextensions enabledelayedexpansion

for /f "tokens=4-7 delims=[.NT] " %%v in ('ver') do (
	if /i "%%v.%%w"=="6.1" if /i %%x LSS 7601  set OLD_WIN=1
	for %%a in (6.0 5.4 5.3 5.2 5.1 5.10 5.0 5.00) do (
		if /i "%%v.%%w"=="%%a"  set OLD_WIN=1
		if /i "%%w.%%x"=="%%a"  set OLD_WIN=1
	)
)

if /i "%PROCESSOR_ARCHITECTURE%"=="X86" (
	set ARCH=x86
	set Programs=%ProgramFiles%
) else (
	set ARCH=x64
	set Programs=%ProgramFiles(x86)%
)

set ARGS=%*
set QUIET=^> nul
set basedir=%~dp0
set basedir=%basedir:~0,-1%
set TMPDIR=%temp%\%~n0
set PyQt_script=%~dpn0.py
set cecho=%basedir%\data\cecho.exe
set repl=%basedir%\data\repl.cmd
set downloadbinary=%basedir%\data\emmcdl.exe
set repos=https://github.com/thefirefox12537/qctools_tff

set protocol=[Enum]::GetNames([Net.SecurityProtocolType])
set current=[Net.SecurityProtocolType]::Tls12

if %OLD_WIN%?==1?  goto :det_oldwinnt

for %%p in ("powershell.exe") do (
	if not exist "%%~$PATH:p"  goto :no_powershell
)

for /f "tokens=*" %%a in ('powershell -noprofile -command "%protocol% -notcontains %current%" 2^> nul') do (
	if /i "%%a"=="true" goto :det_oldpwsh
)

if not exist "%downloadbinary%" (
	mkdir "%basedir%\data\sources" > nul 2>&1
	mkdir "%basedir%\data\sources\emmcdl" > nul 2>&1
	if not exist "%basedir%\data\sources\emmcdl" powershell -noprofile -command ^
	"Invoke-Expression (((Get-Content "%~sf0" | Select-String '^::/') -replace '::/') | Out-String);" ^
	"Download-Manager -uri %repos%/raw/additional/data/sources/emmcdl.zip -target '%TMPDIR%\emmcdl.zip';" ^
	"Extract-Zip -zipfile '%TMPDIR%\emmcdl.zip' -destinationpath '%basedir%\data\sources\emmcdl\';" ^
	"Remove-Item -force '%TMPDIR%\emmcdl.zip'"
	cd "%basedir%\data\sources\emmcdl"

	for /f "tokens=*" %%v in ('where /r "%Programs%\Microsoft Visual Studio" VsDevCmd.bat 2^> nul') do set VS=%%~v
	if not exist "!VS!" powershell -noprofile -command ^
	"Invoke-Expression (((Get-Content "%~sf0" | Select-String '^::/') -replace '::/') | Out-String);" ^
	"Download-Manager -uri https://aka.ms/vs/17/release/vs_BuildTools.exe -target '%TMPDIR%\buildtools.exe';" ^
	"Start-Process -filepath '%TMPDIR%\buildtools.exe'" ^
	"-argumentlist '--add Microsoft.VisualStudio.Workload.MSBuildTools --quiet'" ^
	"-wait -windowstyle hidden -verb runas"

	for /f "tokens=*" %%s in ('type "!VS!" ^| findstr /v /i "exit./B"') do echo %%s >> "%TMPDIR%\tmp_script.bat"
	call "%TMPDIR%\tmp_script.bat" > nul 2>&1
	del /q "%TMPDIR%\tmp_script.bat" > nul 2>&1

	msbuild "%cd%\emmcdl.win32.sln" /p:platform=Win32 /p:configuration=Release > nul 2>&1
	move /y emmcdl.exe "%basedir%\data" > nul 2>&1
	if not exist "%downloadbinary%" goto :no_emmcdl
)

for %%a in ("%basedir%\data\adb.exe" "%basedir%\data\fastboot*.exe") do if not exist "%%~a" set NO_ADB=1
if defined NO_ADB (
	mkdir "%basedir%\data" > nul 2>&1
	powershell -noprofile -command ^
	"Invoke-Expression (((Get-Content "%~sf0" | Select-String '^::/') -replace '::/') | Out-String);" ^
	"Download-Manager -uri https://dl.google.com/android/repository/platform-tools_r28.0.1-windows.zip -target '%TMPDIR%\platform-tools.zip';" ^
	"Extract-Zip -zipfile '%TMPDIR%\platform-tools.zip' -destinationpath '%temp%\';" ^
	"Remove-Item -force '%TMPDIR%\platform-tools.zip'"

	for %%a in (adb.exe AdbWinApi.dll AdbWinUsbApi.dll fastboot.exe) do move /y "%temp%\platform-tools\%%a" "%basedir%\data" > nul 2>&1
	rd /s /q "%temp%\platform-tools" > nul 2>&1
	if not exist "%basedir%\data\adb.exe" goto :no_adb
)

for %%a in (" " "/r "%basedir%"") do ^
for /f "tokens=*" %%p in ('where %%~a python.exe 2^> nul') do ^
if exist "%%~p" set python=%%~p

for /f %%c in ('copy /z "%~f0" nul') do set CR=%%c
cd "%basedir%"

if not defined ARGS (
	if exist "%PyQt_script%" (
		if /i "!python!"=="" (
			echo Requirements:  python
			endlocal & exit /b
		)
		call "!python!" -m pip list 2>&1 | findstr /r /c:"PyQt5.\s" > nul || \
		call "!python!" -m pip install PyQt5
		call "!python!" "%PyQt_script%"
		endlocal
		exit /b
	) else (
		goto :no_pyscript
	)
)

for %%i in (%ARGS:^== %) do (
	if "%%i"=="--list-available"          goto :show_device_list
	if "%%i"=="--version"                 goto :show_credits
	for %%d in (--install-drivers -d) do  if "%%i"=="%%d"  goto :install_drivers
	for %%h in (--help -h) do             if "%%i"=="%%h"  goto :show_usage
	for %%m in (--method -M) do           if "%%i"=="%%m"  set METHOD_ARGS=1
	for %%v in (--verbose -v) do          if "%%i"=="%%v"  set QUIET=
	for %%e in (--reboot-edl -E) do       if "%%i"=="%%e"  (
		set METHOD=edl
		set METHOD_FULL=Reboot to EDL mode
		set REBOOT_EDL=1
	)

	for %%l in (
		a33_cph2137  a53_cph2127  a53s_cph2139  a73_cph2099  a74_cph2219  a76_cph2375  a95_cph2365
		f17_cph2095  f19_cph2219  f21pro_cph2219  reno4old_cph2113  reno4new_cph2113  reno4pro_cph2109
		reno5_cph2159  reno6_cph2235  reno7_cph2363  realme6pro_rmx2061  realme7i_rmx2103  realme7pro_rmx2170
		realme8pro_rmx3091  realme9_rmx3521  realmec15_rmx2195  realmec17_rmx2101  vivo_iq00  vivo_y20_oldsec
		vivo_y20_newsec  vivo_y50t  vivo_y53  vivo_y55  vivo_y65  vivo_y71  vivo_y91  vivo_y93  vivo_y95
		vivo_v9  vivo_v9yth  vivo_v11pro  vivo_v20_newsec  vivo_v21e  mi8ee_ursa  mi8se_sirius  mi8ud_equuleus
		mi9t_raphael  mi10lite_toco  mi11tpro_vili  mia2_jasmine  mia2lite_daisy  mimax2_chiron  mimax3_nitrogen
		mimix_lithium  mimix2s_polaris  mimix3_perseus  minote2_scorpio  minote3_jason  mipad4_clover
		pocof1_beryllium  pocom2pro_gramin  pocom3_citrus  redmi5a_riva  redmi6pro_sakura  redmi7_onclite
		redmi9t_lime  redmik20pro_raphael  note5_whyred  note5pro_whyred  note5a_ugglite  note6pro_tulip
		note8_ginkgo  note9s_curtana  note9pro_joyeuse  sm_a015f  sm_a025f  sm_a115a  sm_a115f  sm_a115u
		sm_a705f  sm_j415f  sm_j610f  sm_m025f  sm_m115f
	) do if "%%i"=="%%l"   set DEVICE=%%l

	if "%%i"=="userdata" (
		set METHOD=userdata
		set METHOD_FULL=Factory Reset
	)
	if "%%i"=="frp" (
		set METHOD=frp
		set METHOD_FULL=Erase FRP
	)
	if "%%i"=="efs" (
		set METHOD=efs
		set METHOD_FULL=Erase EFS IMEI
	)
	if "%%i"=="misc" (
		set METHOD=misc
		set METHOD_FULL=Safe format data
	)
	if "%%i"=="micloud" (
		if not "%SHORT_BRAND%"=="xiaomi" (
			echo This method only allowed for Xiaomi brands.
			endlocal & exit /b
		)
		set METHOD=micloud
		set METHOD_FULL=Erase MiCloud
	)
)

if defined DEVICE      call :%DEVICE%

if not defined METHOD_ARGS  goto :no_method
if not defined METHOD       goto :no_options
if not defined NAME         goto :no_device

call :caption
if %REBOOT_EDL% EQU 1  goto :reboot_edl
call :execution

for %%r in (
	%firehosefile% boot.xml patch.xml
	patch_mod.xml partition.xml
) do ^
del /q "%TMPDIR%\%%r" > nul 2>&1
endlocal
exit /b


:: ######################################################################################################### ::
:: ############################################# MAIN EXECUTION ############################################ ::
:: ######################################################################################################### ::

:execution
for /f "tokens=2*" %%a in ('reg.exe query HKLM\HARDWARE\DEVICEMAP\SERIALCOMM /v \Device\*QCUSB* 2^> nul') do (
	if "%%~b"=="" (goto :no_port) else (set COMPORT=%%~b)
)

call :get_partition
set "current_time=%DATE:~0,2%_%DATE:~3,2%_%DATE:~6,4%__%TIME:~0,2%_%TIME:~3,2%_%TIME:~6,2%"

powershell -noprofile -command ^
"Invoke-Expression (((Get-Content "%~sf0" | Select-String '^::/') -replace '::/') | Out-String);" ^
"Download-Manager -uri %repos%/raw/additional/data/loader/%SHORT_BRAND%/%firehosefile% -target '%TMPDIR%\%firehosefile%';" ^
"Download-Manager -uri %repos%/raw/additional/data/xml/boot.xml -target '%TMPDIR%\boot.xml';" ^
"Download-Manager -uri %repos%/raw/additional/data/xml/patch.xml -target '%TMPDIR%\patch.xml'"

mkdir "%basedir%\data\backup" > nul 2>&1

set "firehose=%TMPDIR%\%firehosefile%"
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
	for %%a in (oppo realme vivo) do if "%SHORT_BRAND%"=="%%a" TMPVAR=1
	if !TMPVAR!==1 (call :process_frp) else (call :process_config)
) else ^
if /i "%METHOD%"=="efs"      (call :process_efs) else ^
if /i "%METHOD%"=="misc"     (call :process_misc) else ^
if /i "%METHOD%"=="micloud"  (call :process_micloud_xiaomi)

if %ERROR_OPT% EQU 1 (pause & exit /b)
call :reboot_device
exit /b

:caption
echo.
echo Selected Model:    %NAME%
echo Selected Brand:    %BRAND%
echo Operation:         %METHOD_FULL%
timeout /nobreak /t 10 > nul
exit /b

:get_partition
set /p "=[ * ]   Configuring device . . .!_CR!" < nul
call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -gpt -memoryname %type% > "%TMPDIR%\partition.xml"
timeout /nobreak /t 1 > nul
"%cecho%" [ {0A}OK{#} ]  Configuring device . . .
exit /b

:process_userdata
for /f "delims= " %%e in ('type "%TMPDIR%\partition.xml" ^| find "userdata"') do (
	set "line=%%e"
	set "line=!line:*userdata =!"
	set /a "result=!line:~1!" 2> nul
)
if "%result%" == "1" (
	for /f "tokens=7 " %%f in ('findstr /i "userdata" "%TMPDIR%\partition.xml"') do echo Partition userdata sector:   %%f
	timeout /nobreak /t 1 > nul
	set /p "=[ * ]   Erasing userdata . . .!_CR!" < nul
	call "%downloadbinary%" -p "%COMPORT%" -f "%firehose%" -e userdata -memoryname "%type%" %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing userdata . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
exit /b

:process_frp
for /f "delims= " %%c in ('type "%TMPDIR%\partition.xml" ^| find "frp"') do (
	set "line=%%c"
	set "line=!line:*frp =!"
	set /a "result=!line:~1!" 2> nul
)
if "%result%" == "1" (
	for /f "tokens=7 " %%d in ('findstr /i "frp" "%TMPDIR%\partition.xml"') do echo Partition FRP sector:   %%d
	timeout /nobreak /t 1 > nul
	set /p "=[ * ]   Erasing FRP . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -e frp -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing FRP . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
exit /b

:process_misc
for /f "delims= " %%e in ('type "%TMPDIR%\partition.xml" ^| find "misc"') do (
	set "line=%%e"
	set "line=!line:*misc =!"
	set /a "result=!line:~1!" 2> nul
)
if "%result%" == "1" (
	for /f "tokens=7 " %%f in ('findstr /i "misc" "%TMPDIR%\partition.xml"') do (
		echo.Partition misc sector:   %%f
		type "%TMPDIR%\patch.xml" | "%repl%" "(start_sector=\q).*?(\q.*>)" "$1%%f$2" xi > "%TMPDIR%\patch_mod.xml"
	)
	timeout /nobreak /t 2 > nul
	set /p "=[ * ]   Backing up misc . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -d misc "%backup_misc%" -memoryname %type% %QUIET%
	"%cecho%" [ OK ]  Backing up misc . . .
	set /p "=[ * ]   Erasing userdata . . .!_CR!" < nul
	call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -x "%TMPDIR%\patch_mod.xml" -memoryname %type% %QUIET%
	"%cecho%" [ {0A}OK{#} ]  Erasing userdata . . .
) else (
	"%cecho%" {0C}ERROR{#}:  %type% damaged.
	set ERROR_OPT=1
)
exit /b

:process_config
if /i "%SHORT_BRAND%"=="samsung" (set TMPVAR=persistent) else (set TMPVAR=config)
for /f "delims= " %%a in ('type "%TMPDIR%\partition.xml" ^| find "%TMPVAR%"') do (
	set "line=%%a"
	set "line=!line:*%TMPVAR% =!"
	set /a "result=!line:~1!" 2> nul
)
if "%result%" == "1" (
	for /f "tokens=7 skip=1 " %%b in ('findstr /i "%TMPVAR%" "%TMPDIR%\partition.xml"') do echo Partition %TMPVAR% sector:   %%b
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
exit /b

:process_micloud_xiaomi
for /f "delims= " %%c in ('type "%TMPDIR%\partition.xml" ^| find "persist"') do (
	set "line=%%c"
	set "line=!line:*persist =!"
	set /a "result=!line:~1!" 2> nul
)
if "%result%" == "1" (
	for /f "tokens=7 " %%d in ('findstr /i "persist" "%TMPDIR%\partition.xml"') do echo Partition persist sector:   %%d
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
exit /b

:process_efs
for /f "delims= " %%c in ('type "%TMPDIR%\partition.xml" ^| find "fsg"') do (
	set "line=%%c"
	set "line=!line:*fsg =!"
	set /a "result=!line:~1!" 2>nul
)
if "%result%" == "1" (
	for /f "tokens=7 " %%d in ('findstr /i "fsg" "%TMPDIR%\partition.xml"') do echo Partition EFS sector:   %%d
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
exit /b

:reboot_device
set /p "=[ * ]   Rebooting device . . .!_CR!" < nul
timeout /nobreak /t 10 > nul
call "%downloadbinary%" -p %COMPORT% -f "%firehose%" -x "%TMPDIR%\boot.xml" -memoryname %type% %QUIET%
"%cecho%" [ {0A}OK{#} ]  Rebooting device . . .
pause
exit /b

:reboot_edl
set /p "=[ * ]   Rebooting device to EDL mode . . .!_CR!" < nul
timeout /nobreak /t 10 > nul
call "%basedir%\fastboot_%SHORT_BRAND%.exe" reboot-edl %QUIET%
"%cecho%" [ {0A}OK{#} ]  Rebooting device to EDL mode . . .
pause
exit /b

:install_drivers
echo Checking drivers installed . . .

where /r "%SystemRoot%\system32\DriverStore\FileRepository" qcser.inf > nul 2>&1 && ^
set "ALREADY=1" || (
	mkdir "%basedir%\data\drivers" > nul 2>&1
	mkdir "%basedir%\data\drivers\qcser" > nul 2>&1

	echo Installing Qualcomm HS-USB QLoader driver . . .
	if not exist "%basedir%\data\drivers\qcser" powershell -noprofile -command ^
	"Invoke-Expression (((Get-Content "%~sf0" | Select-String '^::/') -replace '::/') | Out-String);" ^
	"Download-Manager -uri %repos%/raw/additional/data/drivers/qcser.zip -target '%TMPDIR%\qcser.zip';" ^
	"Extract-Zip -zipfile '%TMPDIR%\qcser.zip' -destinationpath '%basedir%\data\drivers\qcser\'"

	powershell -noprofile -command ^
	"Start-Process -filepath pnputil.exe" ^
	"-argumentlist '-i -a "%basedir%\data\drivers\qcser\%ARCH%\qcser.inf"'" ^
	"-wait -windowstyle hidden -verb runas"
	del /q "%TMPDIR%\qcser.zip" > nul 2>&1
)

where /r "%SystemRoot%\system32\DriverStore\FileRepository" android_winusb.inf > nul 2>&1 && ^
set "ALREADY=1" || (
	mkdir "%basedir%\data\drivers" > nul 2>&1
	mkdir "%basedir%\data\drivers\adb_usb" > nul 2>&1

	echo Installing Android Debug Bridge USB driver . . .
	if not exist "%basedir%\data\drivers\adb_usb" powershell -noprofile -command ^
	"Invoke-Expression (((Get-Content "%~sf0" | Select-String '^::/') -replace '::/') | Out-String);" ^
	"Download-Manager -uri %repos%/raw/additional/data/drivers/adb_usb.zip -target '%TMPDIR%\adb_usb.zip';" ^
	"Extract-Zip -zipfile '%TMPDIR%\adb_usb.zip' -destinationpath '%basedir%\data\drivers\adb_usb\'"

	powershell -noprofile -command ^
	"Start-Process -filepath pnputil.exe" ^
	"-argumentlist '-i -a "%basedir%\data\drivers\adb_usb\android_winusb.inf"'" ^
	"-wait -windowstyle hidden -verb runas"
	del /q "%TMPDIR%\adb_usb.zip" > nul 2>&1
)

if defined ALEADY (
	echo Drivers already installed.
)
exit /b

:powershell_hybrid
::/ function Download-Manager {
::/     param ([Uri]$Uri, [string]$Target)
::/     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
::/     $WebClient = New-Object Net.WebClient
::/     $WebClient.DownloadFile($Uri, $Target) | Out-Null
::/ }
::/
::/ function Extract-Zip {
::/     param ([string]$ZipFile, [string]$DestinationPath)
::/     Add-Type -AssemblyName "System.IO.Compression.FileSystem" | Out-Null
::/     [IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $DestinationPath) | Out-Null
::/ }


:: ######################################################################################################### ::
:: ############################################### MESSAGES ################################################ ::
:: ######################################################################################################### ::

:show_usage
echo USAGE:  %~n0 ^<device^> [OPTION]...
echo.
echo     -d, --install-drivers    install driver
echo     -E, --reboot-edl         reboot device in EDL mode
echo     -h, --help               show help usage
echo     -M, --method             choose what do you execute
echo     -v, --verbose            explain what is being done
echo         --version            show script file version and credits
echo.
echo To see device list, type  %~n0 --list-available
endlocal
exit /b

:show_credits
echo Qualcomm Flasher Tool for Linux
echo Unlock and flash the Android phone devices.
echo Version report:  1.0 revision 1
echo.
echo This script created by Faizal Hamzah [The Firefox Flasher].
echo Licensed under the MIT License.
echo.
echo Credits:
echo     nijel8            Developer of emmcdl binary
echo     bjoerkerler       Qualcomm Firehose Attacker source code
echo     Hari Sulteng      Qualcomm GSM Sulteng
echo     Hadi Khoirudin    Qualcomm Tools, a simple unlocker
endlocal
exit /b

:show_device_list
echo Devices list available in this tools:
echo.
echo Oppo:
echo     a33_cph2137            Oppo A33
echo     a53_cph2127            Oppo A53
echo     a53s_cph2139           Oppo A53S
echo     a73_cph2099            Oppo A73
echo     a74_cph2219            Oppo A74
echo     a76_cph2375            Oppo A76
echo     a95_cph2365            Oppo A95
echo     f17_cph2095            Oppo F17
echo     f19_cph2219            Oppo F19
echo     f21pro_cph2219         Oppo F21 Pro
echo     reno4old_cph2113       Oppo Reno4
echo     reno4new_cph2113       Oppo Reno4
echo     reno4pro_cph2109       Oppo Reno4 Pro
echo     reno5_cph2159          Oppo Reno5
echo     reno6_cph2235          Oppo Reno6
echo     reno7_cph2363          Oppo Reno7
echo.
echo Realme:
echo     realme6pro_rmx2061     Realme 6 Pro
echo     realme7i_rmx2103       Realme 7i
echo     realme7pro_rmx2170     Realme 7 Pro
echo     realme8pro_rmx3091     Realme 8 Pro
echo     realme9_rmx3521        Realme 9
echo     realmec15_rmx2195      Realme C15
echo     realmec17_rmx2101      Realme C17
echo.
echo Vivo:
echo     vivo_iq00              Vivo IQ00 UI
echo     vivo_y20_oldsec        Vivo Y20
echo     vivo_y20_newsec        Vivo Y20
echo     vivo_y50t              Vivo Y50T
echo     vivo_y53               Vivo Y53
echo     vivo_y55               Vivo Y55/L
echo     vivo_y65               Vivo Y65
echo     vivo_y71               Vivo Y71
echo     vivo_y91               Vivo Y91/i
echo     vivo_y93               Vivo Y93
echo     vivo_y95               Vivo Y95
echo     vivo_v9                Vivo V9
echo     vivo_v9yth             Vivo V9 Youth
echo     vivo_v11pro            Vivo V11 Pro
echo     vivo_v20_newsec        Vivo V20
echo     vivo_v21e              Vivo V21E
echo.
echo Xiaomi / Poco:
echo     mi8ee_ursa             Xiaomi Mi 8 EE
echo     mi8se_sirius           Xiaomi Mi 8 SE
echo     mi8ud_equuleus         Xiaomi Mi 8 UD
echo     mi9t_raphael           Xiaomi Mi 9T
echo     mi10lite_toco          Xiaomi Mi 10 Lite
echo     mi11tpro_vili          Xiaomi 11T Pro
echo     mia2_jasmine           Xiaomi Mi A2
echo     mia2lite_daisy         Xiaomi Mi A2 Lite
echo     mimax2_chiron          Xiaomi Mi Max 2
echo     mimax3_nitrogen        Xiaomi Mi Max 3
echo     mimix_lithium          Xiaomi Mi Mix
echo     mimix2s_polaris        Xiaomi Mi Mix 2s
echo     mimix3_perseus         Xiaomi Mi Mix 3
echo     minote2_scorpio        Xiaomi Mi Note 2
echo     minote3_jason          Xiaomi Mi Note 3
echo     mipad4_clover          Xiaomi Mi Pad 4
echo     pocof1_beryllium       Xiaomi Pocophone F1
echo     pocom2pro_gramin       Xiaomi Pocophone M2 Pro
echo     pocom3_citrus          Xiaomi Pocophone M3
echo     redmi5a_riva           Xiaomi Redmi 5A
echo     redmi6pro_sakura       Xiaomi Redmi 6 Pro
echo     redmi7_onclite         Xiaomi Redmi 7
echo     redmi9t_lime           Xiaomi Redmi 9T
echo     redmik20pro_raphael    Xiaomi Redmi K20 Pro
echo     note5_whyred           Xiaomi Redmi Note 5
echo     note5pro_whyred        Xiaomi Redmi Note 5 Pro
echo     note5a_ugglite         Xiaomi Redmi Note 5a
echo     note6pro_tulip         Xiaomi Redmi Note 6 Pro
echo     note8_ginkgo           Xiaomi Redmi Note 8
echo     note9s_curtana         Xiaomi Redmi Note 9S
echo     note9pro_joyeuse       Xiaomi Redmi Note 9 Pro
echo.
echo Samsung:
echo     sm_a015f               Samsung Galaxy A01
echo     sm_a025f               Samsung Galaxy A02s
echo     sm_a115a               Samsung Galaxy A11
echo     sm_a115f               Samsung Galaxy A11
echo     sm_a115u               Samsung Galaxy A11
echo     sm_a705f               Samsung Galaxy A70
echo     sm_j415f               Samsung Galaxy J4 Plus
echo     sm_j610f               Samsung Galaxy J6 Plus
echo     sm_m025f               Samsung Galaxy M02s
echo     sm_m115f               Samsung Galaxy M11
endlocal
exit /b

:no_pyscript
echo This is development release. Coming soon:  GUI window.
endlocal
exit /b

:no_emmcdl
echo emmcdl is not found.
endlocal
exit /b

:no_adb
echo platform-tools is not found.
endlocal
exit /b

:no_method
echo Invalid switch parameter.
endlocal
exit /b

:no_options
echo No option inserted.
endlocal
exit /b

:no_device
echo Device is not availabled.
endlocal
exit /b

:no_port
echo.& echo Error:  Qualcomm HS-USB port not detected.
echo.& pause
endlocal
exit /b

:no_powershell
echo This script requires Windows Management Framework (PowerShell^).
endlocal
exit /b

:det_oldpwsh
echo This script requires at least .NET Framework version 4.5 and Windows Management Framework version 4.0.
endlocal
exit /b

:det_oldwinnt
echo This script requires Windows 7 Service Pack 1 or latest.
endlocal
exit /b


:: ######################################################################################################### ::
:: ###################################### DEVICE LIST SET VARIABLE ######################################### ::
:: ######################################################################################################### ::

:: ############################################# START OPPO ################################################ ::

:a33_cph2137
set NAME=Oppo A33 (CPH-2137^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a33_cph2137
set firehosefile=prog_firehose_ddr_Oppo_A33_A53_A53s.elf
set type=emmc
exit /b

:a53_cph2127
set NAME=Oppo A53 (CPH-2127^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a53_cph2127
set firehosefile=prog_firehose_ddr_Oppo_A33_A53_A53s.elf
set type=ufs
exit /b

:a53s_cph2139
set NAME=Oppo A53s (CPH-2139^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a53s_cph2139
set firehosefile=prog_firehose_ddr_Oppo_A33_A53_A53s.elf
set type=emmc
exit /b

:a73_cph2099
set NAME=Oppo A73 (CPH-2099^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a73_cph2099
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:a74_cph2219
set NAME=Oppo A74 (CPH-2219^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a74_cph2219
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:a76_cph2375
set NAME=Oppo A76 (CPH-2375^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a76_cph2375
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:a95_cph2365
set NAME=Oppo A95 (CPH-2365^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=a95_cph2365
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:f17_cph2095
set NAME=Oppo F17 (CPH-2095^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=f17_cph2095
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:f19_cph2219
set NAME=Oppo F19 (CPH-2219^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=f19_cph2219
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:f21pro_cph2219
set NAME=Oppo F21 Pro (CPH-2219^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=f21pro_cph2219
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:reno4old_cph2113
set NAME=Oppo Reno4 (CPH-2113^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno4_cph2113
set firehosefile=prog_firehose_ddr_OppoReno4OldSec2019.mbn
set type=ufs
exit /b

:reno4new_cph2113
set NAME=Oppo Reno4 (CPH-2113^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno4_cph2113
set firehosefile=prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf
type=ufs
exit /b

:reno4pro_cph2109
set NAME=Oppo Reno4 Pro (CPH-2109^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno4pro_cph2109
set firehosefile=prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf
set type=ufs
exit /b

:reno5_cph2159
set NAME=Oppo Reno5 (CPH-2159^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno5_cph2159
set firehosefile=prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf
set type=ufs
exit /b

:reno6_cph2235
set NAME=Oppo Reno6 (CPH-2235^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno6_cph2235
set firehosefile=prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf
set type=ufs
exit /b

:reno7_cph2363
set NAME=Oppo Reno7 (CPH-2363^)
set BRAND=Oppo/Realme
set SHORT_BRAND=oppo
set DEVICE=reno7_cph2363
set firehosefile=prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf
set type=ufs
exit /b

:: ############################################## END OPPO ################################################# ::
:: ############################################ START REALME ############################################### ::

:realme6pro_rmx2061
set NAME=Realme 6 Pro (RMX-2061^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=6pro_rmx2061
set firehosefile=prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf
set type=ufs
exit /b

:realme7i_rmx2103
set NAME=Realme 7i (RMX-2103^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=7i_rmx2103
set firehosefile=prog_firehose_ddr_Realme7iRMX2103_Realme9RMX3521.elf
set type=ufs
exit /b

:realme7pro_rmx2170
set NAME=Realme 7 Pro (RMX-2170^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=7pro_rmx2170
set firehosefile=prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf
set type=ufs
exit /b

:realme8pro_rmx3091
set NAME=Realme 8 Pro (RMX-3091^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=8pro_rmx3091
set firehosefile=prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf
set type=ufs
exit /b

:realme9_rmx3521
set NAME=Realme 9 (RMX-3521^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=9_rmx3521
set firehosefile=prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf
set type=ufs
exit /b

:realmec15_rmx2195
set NAME=Realme C15 (RMX-2195^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=c15_rmx2195
set firehosefile=prog_firehose_ddr_RealmeC15RMX2195_RealmeC17_RMX2101.elf
set type=emmc
exit /b

:realmec17_rmx2101
set NAME=Realme C17 (RMX-2101^)
set BRAND=Oppo/Realme
set SHORT_BRAND=realme
set DEVICE=c17_rmx2101
set firehosefile=prog_firehose_ddr_RealmeC15RMX2195_RealmeC17_RMX2101.elf
set type=ufs
exit /b

:: ############################################# END REALME ################################################ ::
:: ############################################# START VIVO ################################################ ::

:vivo_iq00
set NAME=Vivo IQ00 UI
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=iq00
set firehosefile=prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf
set type=ufs
exit /b

:vivo_y20_oldsec
set NAME=Vivo Y20
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y20
set firehosefile=prog_firehose_ddr_vivo_Y20_Y20i_Y20s.elf
set type=emmc
exit /b

:vivo_y20_newsec
set NAME=Vivo Y20
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y20
set firehosefile=prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf
set type=emmc
exit /b

:vivo_y50t
set NAME=Vivo Y50T
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y50t
set firehosefile=prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf
set type=ufs
exit /b

:vivo_y53
set NAME=Vivo Y53
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y53
set firehosefile=prog_firehose_8917_ddr_vivo_y53_y53l.mbn
set type=emmc
exit /b

:vivo_y55
set NAME=Vivo Y55/L
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y55
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
exit /b

:vivo_y65
set NAME=Vivo Y65
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y65
set firehosefile=prog_firehose_8917_ddr_vivo_y65.mbn
set type=emmc
exit /b

:vivo_y71
set NAME=Vivo Y71
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y71
set firehosefile=prog_firehose_8917_ddr_vivo_y71.mbn
set type=emmc
exit /b

:vivo_y91
set NAME=Vivo Y91/i
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y91
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
exit /b

:vivo_y93
set NAME=Vivo Y93
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y93
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
exit /b

:vivo_y95
set NAME=Vivo Y95
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=y95
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
exit /b

:vivo_v9
set NAME=Vivo V9
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v9
set firehosefile=prog_emmc_firehose_8953_ddr_vivo_v9.mbn
set type=emmc
exit /b

:vivo_v9yth
set NAME=Vivo V9 Youth
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v9yth
set firehosefile=prog_emmc_firehose_8953_ddr_vivo_v9_youth.mbn
set type=emmc
exit /b

:vivo_v11pro
set NAME=Vivo V11 Pro
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v11pro
set firehosefile=prog_emmc_firehose_8937_y91_y93_y95_v11.mbn
set type=emmc
exit /b

:vivo_v20_newsec
set NAME=Vivo V20
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v20
set firehosefile=prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf
set type=ufs
exit /b

:vivo_v21e
set NAME=Vivo V21E
set BRAND=Vivo
set SHORT_BRAND=vivo
set DEVICE=v21e
set firehosefile=prog_firehose_ddr_vivo_V21e.elf
set type=ufs
exit /b

:: ############################################## END VIVO ################################################# ::
:: ############################################# START XIAOMI ############################################## ::

:mi8ee_ursa
set NAME=Xiaomi Mi 8 EE (Ursa^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=ursa
set firehosefile=prog_ufs_firehose_sdm845_ddr_mi8ee_ursa_sig_rb1.elf
set type=ufs
exit /b

:mi8se_sirius
set NAME=Xiaomi Mi 8 SE (Sirius^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=sirius
set firehosefile=prog_emmc_firehose_Sdm670_ddr_xiaomi_mi8se_sirius_sig_rb1.mbn
set type=emmc
exit /b

:mi8ud_equuleus
set NAME=Xiaomi Mi 8 UD (Equuleus^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=equuleus
set firehosefile=prog_ufs_firehose_sdm845_ddr_mi8ud_equuleus_sig_rb1.elf
set type=ufs
exit /b

:mi9t_raphael
set NAME=Xiaomi Mi 9T (Raphael^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=raphael
set firehosefile=prog_ufs_firehose_sdm845_ddr_Mi9T.elf
set type=ufs
exit /b

:mi10lite_toco
set NAME=Xiaomi Mi 10 Lite (Toco^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=toco
set firehosefile=prog_ufs_firehose_MiNote10Lite.elf
set type=ufs
exit /b

:mi11tpro_vili
set NAME=Xiaomi 11T Pro (Vili^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=vili
set firehosefile=prog_ufs_firehose_Mi11TProUFS.elf
set type=ufs
exit /b

:mia2_jasmine
set NAME=Xiaomi Mi A2 (Jasmine^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=jasmine
set firehosefile=prog_emmc_firehose_Sdm660_ddr_mia2_jasmine_rb2.elf
set type=emmc
exit /b

:mia2lite_daisy
set NAME=Xiaomi Mi A2 Lite (Daisy^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=daisy
set firehosefile=prog_emmc_firehose_8953_ddr_mia2lite_daisy_rb1.mbn
set type=emmc
exit /b

:mimax2_chiron
set NAME=Xiaomi Mi Max 2 (Chiron^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=chiron
set firehosefile=prog_ufs_firehose_8998_ddr_xiaomi_mimax2_chiron_rb1.elf
set type=ufs
exit /b

:mimax3_nitrogen
set NAME=Xiaomi Mi Max 3 (Nitrogen^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=nitrogen
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi1_mimax3_nitrogen_rb4.elf
set type=emmc
exit /b

:mimix_lithium
set NAME=Xiaomi Mi Mix (Lithium^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=lithium
set firehosefile=prog_ufs_firehose_8996_ddr_xiaomi_mimix_lithium_rb1.elf
set type=ufs
exit /b

:mimix2s_polaris
set NAME=Xiaomi Mi Mix 2s (Polaris^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=polaris
set firehosefile=prog_ufs_firehose_Sdm845_ddr_xiaomi_sig_mimix2s_polaris_rb1.elf
set type=ufs
exit /b

:mimix3_perseus
set NAME=Xiaomi Mi Mix 3 (Perseus^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=perseus
set firehosefile=prog_ufs_firehose_sdm845_ddr_sig_mimix3_perseus_rb2.elf
set type=ufs
exit /b

:minote2_scorpio
set NAME=Xiaomi Mi Note 2 (Jason^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=scorpio
set firehosefile=prog_ufs_firehose_8996_ddr_xiaomi_minote2_scorpio_rb1.elf
set type=ufs
exit /b

:minote3_jason
set NAME=Xiaomi Mi Note 3 (Jason^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=jason
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_minote3_jason_rb1.elf
set type=emmc
exit /b

:mipad4_clover
set NAME=Xiaomi Mi Pad 4 (Clover^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=clover
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_mipad4_clover_s_rb4.elf
set type=emmc
exit /b

:pocof1_beryllium
set NAME=Xiaomi Pocophone F1 (Beryllium^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=beryllium
set firehosefile=prog_ufs_firehose_sdm845_ddr_pocof1_beryllium_sig_rb1.mbn
set type=ufs
exit /b

:pocom2pro_gramin
set NAME=Xiaomi Pocophone M2 Pro (Gramin^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=gramin
set firehosefile=prog_ufs_firehose_MiPocoM2Pro.elf
set type=ufs
exit /b

:pocom3_citrus
set NAME=Xiaomi Pocophone M3 (Citrus^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=citrus
set firehosefile=prog_ufs_firehose_sdm845_ddr_MiPocoM3.elf
set type=ufs
exit /b

:redmi5a_riva
set NAME=Xiaomi Redmi 5A (Riva^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=riva
set firehosefile=prog_emmc_firehose_8953_ddr_xiaomi_redmi5a.mbn
set type=emmc
exit /b

:redmi6pro_sakura
set NAME=Xiaomi Redmi 6 Pro (Sakura^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=sakura
set firehosefile=prog_emmc_firehose_8953_ddr_xiaomi_6pro_sakura_rb1.mbn
set type=emmc
exit /b

:redmi7_onclite
set NAME=Xiaomi Redmi 7 (Onclite^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=onclite
set firehosefile=prog_emmc_firehose_8953_ddr_redmi7.mbn
set type=emmc
exit /b

:redmi9t_lime
set NAME=Xiaomi Redmi 9T (Lime^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=lime
set firehosefile=prog_ufs_firehose_sdm845_ddr_Mi9Power.elf
set type=ufs
exit /b

:redmik20pro_raphael
set NAME=Xiaomi Redmi K20 Pro (Raphael^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=raphael
set firehosefile=prog_ufs_firehose_RedmiK20Pro.elf
set type=ufs
exit /b

:note5_whyred
set NAME=Xiaomi Redmi Note 5 (Whyred^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=whyred
set firehosefile=prog_emmc_firehose_Sdm660_ddr_note5_whyred_s_rb4.elf
set type=emmc
exit /b

:note5pro_whyred
set NAME=Xiaomi Redmi Note 5 Pro (Whyred^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=whyred
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_note5pro_whyred_s_rb4.elf
set type=emmc
exit /b

:note5a_ugglite
set NAME=Xiaomi Redmi Note 5A (Ugglite^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=ugglite
set firehosefile=prog_emmc_firehose_8917_ddr_note5a_ugglite.mbn
set type=emmc
exit /b

:note6pro_tulip
set NAME=Xiaomi Redmi Note 6 Pro (Tulip^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=tulip
set firehosefile=prog_emmc_firehose_Sdm660_ddr_xiaomi_note6pro_tulip_s_rb4.elf
set type=emmc
exit /b

:note8_ginkgo
set NAME=Xiaomi Redmi Note 8 (Ginkgo^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=ginkgo
set firehosefile=prog_ufs_firehose_RedmiNote8.elf
set type=ufs
exit /b

:note9s_curtana
set NAME=Xiaomi Redmi Note 9S (Curtana^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=curtana
set firehosefile=prog_ufs_firehose_MiNote9s.elf
set type=ufs
exit /b

:note9pro_joyeuse
set NAME=Xiaomi Redmi Note 9 Pro (Joyeuse^)
set BRAND=Xiaomi
set SHORT_BRAND=xiaomi
set DEVICE=joyeuse
set firehosefile=prog_ufs_firehose_MiNote9Pro.elf
set type=ufs
exit /b

:: ############################################# END XIAOMI ################################################ ::
:: ############################################ START SAMSUNG ############################################## ::

:sm_a015f
set NAME=Samsung Galaxy A01 (SM-A015F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a015f
set firehosefile=prog_emmc_firehose_8937_A015F.mbn
set type=emmc
exit /b

:sm_a025f
set NAME=Samsung Galaxy A02s (SM-A025F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a025f
set firehosefile=prog_emmc_firehose_8937_A025F.mbn
set type=emmc
exit /b

:sm_a115a
set NAME=Samsung Galaxy A11 (SM-A115A^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a115a
set firehosefile=prog_emmc_firehose_8953_A115A.mbn
set type=emmc
exit /b

:sm_a115f
set NAME=Samsung Galaxy A11 (SM-A115F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a115f
set firehosefile=prog_emmc_firehose_8953_A115F.mbn
set type=emmc
exit /b

:sm_a115u
set NAME=Samsung Galaxy A11 (SM-A115U^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a115u1
set firehosefile=prog_emmc_firehose_8953_A115U.mbn
set type=emmc
exit /b

:sm_a705f
set NAME=Samsung Galaxy A70 (SM-A705F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_a705f
set firehosefile=prog_ufs_firehose_ddr_A705F.mbn
set type=ufs
exit /b

:sm_j415f
set NAME=Samsung Galaxy J4 Plus (SM-J415F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_j415f
set firehosefile=prog_ufs_firehose_8917_J415F.mbn
set type=ufs
exit /b

:sm_j610f"
set NAME=Samsung Galaxy J6 Plus (SM-J610F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_j610f
set firehosefile=prog_ufs_firehose_8917_J610F.mbn
set type=ufs
exit /b

:sm_m025f
set NAME=Samsung Galaxy M02s (SM-M02s^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_m025f
set firehosefile=prog_emmc_firehose_8953_M025F.mbn
set type=emmc
exit /b

:sm_m115f
set NAME=Samsung Galaxy M11 (SM-M115F^)
set BRAND=Samsung
set SHORT_BRAND=samsung
set DEVICE=sm_m115f
set firehosefile=prog_emmc_firehose_8953_M115F.mbn
set type=emmc
exit /b

:: ############################################# END SAMSUNG ############################################### ::


:: end_batch_script
cmd
## begin_bash_script


[ -e /etc/os-release ] && \
. /etc/os-release 2>/dev/null || \
. /usr/lib/os-release 2>/dev/null

[[ "$ID" =~ "debian" || "$ID_LIKE" =~ "debian" || "$ID_LIKE" =~ "ubuntu" ]] && DIST_CORE="debian"
[[ "$ID" =~ "rhel"   || "$ID_LIKE" =~ "rhel"   || "$ID_LIKE" =~ "redhat" ]] && DIST_CORE="redhat"
[[ "$ID" =~ "fedora" || "$ID_LIKE" =~ "fedora" ]] && DIST_CORE="redhat_fedora"
[[ "$ID" =~ "suse"   || "$ID_LIKE" =~ "suse"   ]] && DIST_CORE="suse"
[[ "$ID" =~ "arch"   || "$ID_LIKE" =~ "arch"   ]] && DIST_CORE="archlinux"

ARGS="$*"
QUIET=">/dev/null"
basefile="$(readlink -f "${0}" | sed 's/\.[^.]*$//')"
basedir="$(dirname "${basefile}")"
TMPDIR="/var/tmp/$(basename "${basefile}")"
PyQt_script="${basefile}.py"
downloadbinary="$basedir/data/emmcdl"
repos="https://github.com/thefirefox12537/qctools_tff"

if [[ -z "$DIST_CORE" ]]; then
	echo "This script cannot be run in this Linux distribution."
	exit 1
elif [[ $(uname -sr) < "Linux 4.4"* ]]; then
	echo "This script requires at least Linux Kernel version 4.4."
	exit 1
fi

if [ ! -d "$TMPDIR" ]; then mkdir -p "$TMPDIR"; fi
if [ ! -x "$downloadbinary" ] ; then
	mkdir -p "$basedir/data/sources" >/dev/null 2>&1
	for x in "wget" "unzip" "aclocal" "autoconf" "automake" "make"; do
	command -v $x >/dev/null 2>&1 || {
		echo "$x is not found."
		exit 1
	}
	done

	[ -d "$basedir/data/sources/emmcdl" ] || {
		wget -qO /var/tmp/emmcdl.zip $repos/raw/additional/data/sources/emmcdl.zip
		unzip -q /var/tmp/emmcdl.zip -d "$basedir/data/sources/emmcdl"
	}
	[ -d "$basedir/data/sources/emmcdl" ] && cd "$basedir/data/sources/emmcdl"
	( aclocal && autoconf && automake --add-missing ) >/dev/null 2>&1
	( ./configure --quiet && make --quiet ) >/dev/null 2>&1
	mv emmcdl "$downloadbinary" >/dev/null 2>&1 || {
		echo "emmcdl is not found."
		exit 1
	}
fi

for a in adb fastboot; do
command -v $a >/dev/null 2>&1 || ls "$basedir/data/$a" >/dev/null 2>&1 || \
NO_ADB=1
done
if [ ! -z $NO_ADB ] ; then
	mkdir -p "$basedir/data" >/dev/null 2>&1
	for x in "wget" "unzip"; do
	command -v $x >/dev/null 2>&1 || {
		echo "$x is not found."
		exit 1
	}
	done

	wget -qO /var/tmp/platform-tools.zip https://dl.google.com/android/repository/platform-tools_r28.0.1-linux.zip
	unzip -q /var/tmp/platform-tools.zip -d "/var/tmp"
	for a in adb fastboot; do
	mv /var/tmp/platform-tools/$a "$basedir/$a" >/dev/null 2>&1 || {
		echo "platform-tools is not found."
		exit 1
	}
	done
	rm -rf /var/tmp/platform-tools /var/tmp/platform-tools.zip >/dev/null 2>&1
fi
PATH="$basedir/data:$PATH"
cd "$basedir"

# #########################################################################################################
# ############################################# MAIN EXECUTION ############################################
# #########################################################################################################

current_time() {
	date +%m_%d_%Y__%H_%M_%S
}

execution() {
	lsusb 2>&1 | grep "Qualcomm.*USB" >/dev/null || {
		printf "%s\n" $'\n'"Error:  Qualcomm HS-USB port not detected."$'\n'
		exit 1
	}

	get_partition

	wget -qO "$TMPDIR/$firehosefile" $repos/raw/additional/data/loader/$SHORT_BRAND/$firehosefile
	wget -qO "$TMPDIR/boot.xml" $repos/raw/additional/data/xml/boot.xml
	wget -qO "$TMPDIR/patch.xml" $repos/raw/additional/data/xml/patch.xml
	mkdir -p "$basedir/data/backup" >/dev/null 2>&1

	firehose="$TMPDIR/$firehosefile"
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
		  [ $TMPVAR -eq 1 ] && \
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
	printf "%s" "
Selected Model:    $NAME
Selected Brand:    $BRAND
Operation:         $METHOD_FULL
"
	sleep 10
}

get_partition() {
	echo $'[ * ]   Configuring device . . . \r'
	eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -gpt -memoryname $type > "$TMPDIR/partition.xml"
	sleep 1
	echo $'[ \e[1;32mOK\e[0m ]  Configuring device . . . '
}

process_userdata() {
	for f in $(cat $TMPDIR/partition.xml | tr -d ' '); do
		[ "${f//*userdata /}" == "1" ] && {
			echo "Partition userdata sector:   $(grep "userdata" "$TMPDIR/partition.xml" | cut -f7)"
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
	for f in $(cat $TMPDIR/partition.xml | tr -d ' '); do
		[ "${f//*frp /}" == "1" ] && {
			echo "Partition FRP sector:   $(grep "frp" "$TMPDIR/partition.xml" | cut -f7)"
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
	for f in $(cat $TMPDIR/partition.xml | tr -d ' '); do
		[ "${f//*misc /}" == "1" ] && {
			for sector in $(grep "misc" "$TMPDIR/partition.xml" | cut -f7); do
				echo "Partition misc sector:   $sector"
				sed -E "s/(start_sector=\").*?(\".*[a-z]=\".*[a-z]=\".*>)/\1${sector}\2/" \
				"$TMPDIR/patch.xml" > "$TMPDIR/patch_mod.xml"
			done
			sleep 2
			echo $'[ * ]   Backing up misc . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d misc "$backup_misc" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up misc . . . '
			echo $'[ * ]   Erasing userdata . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -x "$TMPDIR/patch_mod.xml" -memoryname $type $QUIET
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
	for f in $(cat $TMPDIR/partition.xml | grep "$TMPVAR" | tr -d ' '); do
		[ "${f//*$TMPVAR /}" == "1" ] && {
			echo "Partition $TMPVAR sector:   $(grep "$TMPVAR" "$TMPDIR/partition.xml" | cut -f7)"
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
	for f in $(cat $TMPDIR/partition.xml | grep "persist" | tr -d ' '); do
		[ "${f//*persist /}" == "1" ] && {
			echo "Partition persist sector:   $(grep "persist" "$TMPDIR/partition.xml" | cut -f7)"
			sleep 1
			echo $'[ * ]   Backing up persist . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d persist "$backup_persist" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up persist . . . '
			echo $'[ * ]   Backing up persistbak . . . \r'
			eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -d persistbak "$backup_persistbak" -memoryname $type $QUIET
			echo $'[ \e[1;32mOK\e[0m ]  Backing up persistbak . . . '
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
	for f in $(cat $TMPDIR/partition.xml | grep "fsg" | tr -d ' '); do
		[ "${f//*fsg /}" == "1" ] && {
			echo "Partition EFS sector:   $(grep "fsg" "$TMPDIR/partition.xml" | cut -f7)"
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
	eval "$downloadbinary" -p ttyUSB0 -f "$firehose" -x "$TMPDIR/boot.xml" -memoryname $type $QUIET
	echo $'[ \e[1;32mOK\e[0m ]  Rebooting device . . . '
	pause
}

reboot_edl() {
	echo $'[ * ]   Rebooting device to EDL mode . . . \r'
	eval fastboot reboot-edl $QUIET
	echo $'[ \e[1;32mOK\e[0m ]  Rebooting device to EDL mode . . . '
}

pause() {
	echo -n "Press any key to continue . . . "
	read -srn1; echo
}

show_usage() {
	printf "%s" "\
USAGE:  $0 <device> [OPTION]...

    -E, --reboot-edl    reboot device in EDL mode
    -h, --help          show help usage
    -M, --method        choose what do you execute
    -v, --verbose       explain what is being done
        --version       show script file version and credits

To see device list, type  $0 --list-available
"
}

show_credits() {
	printf "%s" "\
Qualcomm Flasher Tool for Linux
Unlock and flash the Android phone devices.
Version report:  1.0 revision 1

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

Oppo:
    a33_cph2137            Oppo A33
    a53_cph2127            Oppo A53
    a53s_cph2139           Oppo A53S
    a73_cph2099            Oppo A73
    a74_cph2219            Oppo A74
    a76_cph2375            Oppo A76
    a95_cph2365            Oppo A95
    f17_cph2095            Oppo F17
    f19_cph2219            Oppo F19
    f21pro_cph2219         Oppo F21 Pro
    reno4old_cph2113       Oppo Reno4
    reno4new_cph2113       Oppo Reno4
    reno4pro_cph2109       Oppo Reno4 Pro
    reno5_cph2159          Oppo Reno5
    reno6_cph2235          Oppo Reno6
    reno7_cph2363          Oppo Reno7

Realme:
    realme6pro_rmx2061     Realme 6 Pro
    realme7i_rmx2103       Realme 7i
    realme7pro_rmx2170     Realme 7 Pro
    realme8pro_rmx3091     Realme 8 Pro
    realme9_rmx3521        Realme 9
    realmec15_rmx2195      Realme C15
    realmec17_rmx2101      Realme C17

Vivo:
    vivo_iq00              Vivo IQ00 UI
    vivo_y20_oldsec        Vivo Y20
    vivo_y20_newsec        Vivo Y20
    vivo_y50t              Vivo Y50T
    vivo_y53               Vivo Y53
    vivo_y55               Vivo Y55/L
    vivo_y65               Vivo Y65
    vivo_y71               Vivo Y71
    vivo_y91               Vivo Y91/i
    vivo_y93               Vivo Y93
    vivo_y95               Vivo Y95
    vivo_v9                Vivo V9
    vivo_v9yth             Vivo V9 Youth
    vivo_v11pro            Vivo V11 Pro
    vivo_v20_newsec        Vivo V20
    vivo_v21e              Vivo V21E

Xiaomi / Poco:
    mi8ee_ursa             Xiaomi Mi 8 EE
    mi8se_sirius           Xiaomi Mi 8 SE
    mi8ud_equuleus         Xiaomi Mi 8 UD
    mi9t_raphael           Xiaomi Mi 9T
    mi10lite_toco          Xiaomi Mi 10 Lite
    mi11tpro_vili          Xiaomi 11T Pro
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
    pocom2pro_gramin       Xiaomi Pocophone M2 Pro
    pocom3_citrus          Xiaomi Pocophone M3
    redmi5a_riva           Xiaomi Redmi 5A
    redmi6pro_sakura       Xiaomi Redmi 6 Pro
    redmi7_onclite         Xiaomi Redmi 7
    redmi9t_lime           Xiaomi Redmi 9T
    redmik20pro_raphael    Xiaomi Redmi K20 Pro
    note5_whyred           Xiaomi Redmi Note 5
    note5pro_whyred        Xiaomi Redmi Note 5 Pro
    note5a_ugglite         Xiaomi Redmi Note 5a
    note6pro_tulip         Xiaomi Redmi Note 6 Pro
    note8_ginkgo           Xiaomi Redmi Note 8
    note9s_curtana         Xiaomi Redmi Note 9S
    note9pro_joyeuse       Xiaomi Redmi Note 9 Pro

Samsung:
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

for i in $(printf "%s" "$ARGS" | sed "s/=/ /g"); do
# ########################################## START OPPO ###################################################

case $i in
	"a33_cph2137" )
	  NAME="Oppo A33 (CPH-2137)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a33_cph2137"
	  firehosefile="prog_firehose_ddr_Oppo_A33_A53_A53s.elf"
	  type="emmc"
	  ;;
	"a53_cph2127" )
	  NAME="Oppo A53 (CPH-2127)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a53_cph2127"
	  firehosefile="prog_firehose_ddr_Oppo_A33_A53_A53s.elf"
	  type="ufs"
	  ;;
	"a53s_cph2139" )
	  NAME="Oppo A53s (CPH-2139)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a53s_cph2139"
	  firehosefile="prog_firehose_ddr_Oppo_A33_A53_A53s.elf"
	  type="emmc"
	  ;;
	"a73_cph2099" )
	  NAME="Oppo A73 (CPH-2099)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a73_cph2099"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"a74_cph2219" )
	  NAME="Oppo A74 (CPH-2219)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a74_cph2219"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"a76_cph2375" )
	  NAME="Oppo A76 (CPH-2375)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a76_cph2375"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"a95_cph2365" )
	  NAME="Oppo A95 (CPH-2365)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="a95_cph2365"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"f17_cph2095" )
	  NAME="Oppo F17 (CPH-2095)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="f17_cph2095"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"f19_cph2219" )
	  NAME="Oppo F19 (CPH-2219)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="f19_cph2219"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"f21pro_cph2219" )
	  NAME="Oppo F21 Pro (CPH-2219)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="f21pro_cph2219"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
	"reno4old_cph2113" )
	  NAME="Oppo Reno4 (CPH-2113)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno4_cph2113"
	  firehosefile="prog_firehose_ddr_OppoReno4OldSec2019.mbn"
	  type="ufs"
	  ;;
	"reno4new_cph2113" )
	  NAME="Oppo Reno4 (CPH-2113)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno4_cph2113"
	  firehosefile="prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf"
	  type="ufs"
	  ;;
	"reno4pro_cph2109" )
	  NAME="Oppo Reno4 Pro (CPH-2109)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno4pro_cph2109"
	  firehosefile="prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf"
	  type="ufs"
	  ;;
	"reno5_cph2159" )
	  NAME="Oppo Reno5 (CPH-2159)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno5_cph2159"
	  firehosefile="prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf"
	  type="ufs"
	  ;;
	"reno6_cph2235" )
	  NAME="Oppo Reno6 (CPH-2235)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno6_cph2235"
	  firehosefile="prog_firehose_ddr_Oppo_Reno4NewSec2021CPH2113_Reno4ProCPH2109_Reno5CPH2159_Reno4G_Reno6CPH2235.elf"
	  type="ufs"
	  ;;
	"reno7_cph2363" )
	  NAME="Oppo Reno7 (CPH-2363)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="oppo"
	  DEVICE="reno7_cph2363"
	  firehosefile="prog_firehose_ddr_OppoReno7CPH2363_OppoA73CPH2099_OppoA74CPH2119_OppoA76CPH2375_OppoA95CPH2365_OppoF17CPH2095_OppoF19CPH2219_OppoF21PRO.elf"
	  type="ufs"
	  ;;
esac

# ########################################### END OPPO ####################################################
# ######################################### START REALME ##################################################

case $i in
	"realme6pro_rmx2061" )
	  NAME="Realme 6 Pro (RMX-2061)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="6pro_rmx2061"
	  firehosefile="prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf"
	  type="ufs"
	  ;;
	"realme7i_rmx2103" )
	  NAME="Realme 7i (RMX-2103)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="7i_rmx2103"
	  firehosefile="prog_firehose_ddr_Realme7iRMX2103_Realme9RMX3521.elf"
	  type="ufs"
	  ;;
	"realme7pro_rmx2170" )
	  NAME="Realme 7 Pro (RMX-2170)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="7pro_rmx2170"
	  firehosefile="prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf"
	  type="ufs"
	  ;;
	"realme8pro_rmx3091" )
	  NAME="Realme 8 Pro (RMX-3091)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="8pro_rmx3091"
	  firehosefile="prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf"
	  type="ufs"
	  ;;
	"realme9_rmx3521" )
	  NAME="Realme 9 (RMX-3521)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="9_rmx3521"
	  firehosefile="prog_firehose_ddr_Realme6Pro_Realme7Pro_Realme8Pro.elf"
	  type="ufs"
	  ;;
	"realmec15_rmx2195" )
	  NAME="Realme C15 (RMX-2195)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="c15_rmx2195"
	  firehosefile="prog_firehose_ddr_RealmeC15RMX2195_RealmeC17_RMX2101.elf"
	  type="emmc"
	  ;;
	"realmec17_rmx2101" )
	  NAME="Realme C17 (RMX-2101)"
	  BRAND="Oppo/Realme"
	  SHORT_BRAND="realme"
	  DEVICE="c17_rmx2101"
	  firehosefile="prog_firehose_ddr_RealmeC15RMX2195_RealmeC17_RMX2101.elf"
	  type="ufs"
	  ;;
esac

# ########################################## END REALME ###################################################
# ########################################## START VIVO ###################################################

case $i in
	"vivo_iq00" )
	  NAME="Vivo IQ00 UI"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="iq00"
	  firehosefile="prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf"
	  type="ufs"
	  ;;
	"vivo_y20_oldsec" )
	  NAME="Vivo Y20"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y20"
	  firehosefile="prog_firehose_ddr_vivo_Y20_Y20i_Y20s.elf"
	  type="emmc"
	  ;;
	"vivo_y20_newsec" )
	  NAME="Vivo Y20"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y20"
	  firehosefile="prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf"
	  type="emmc"
	  ;;
	"vivo_y50t" )
	  NAME="Vivo Y50T"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y50t"
	  firehosefile="prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf"
	  type="ufs"
	  ;;
	"vivo_y53" )
	  NAME="Vivo Y53"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y53"
	  firehosefile="prog_firehose_8917_ddr_vivo_y53_y53l.mbn"
	  type="emmc"
	  ;;
	"vivo_y55" )
	  NAME="Vivo Y55/L"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y55"
	  firehosefile="prog_emmc_firehose_8937_y91_y93_y95_v11.mbn"
	  type="emmc"
	  ;;
	"vivo_y65" )
	  NAME="Vivo Y65"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y65"
	  firehosefile="prog_firehose_8917_ddr_vivo_y65.mbn"
	  type="emmc"
	  ;;
	"vivo_y71" )
	  NAME="Vivo Y71"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="y71"
	  firehosefile="prog_firehose_8917_ddr_vivo_y71.mbn"
	  type="emmc"
	  ;;
	"vivo_y91" )
	  NAME="Vivo Y91/i"
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
	"vivo_v20_newsec" )
	  NAME="Vivo V20"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="v20"
	  firehosefile="prog_firehose_ddr_vivo_IQOOU1_Y20_Y50T_V20.elf"
	  type="ufs"
	  ;;
	"vivo_v21e" )
	  NAME="Vivo V21E"
	  BRAND="Vivo"
	  SHORT_BRAND="vivo"
	  DEVICE="v21e"
	  firehosefile="prog_firehose_ddr_vivo_V21e.elf"
	  type="ufs"
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
	"mi9t_raphael" )
	  NAME="Xiaomi Mi 9T (Raphael)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="raphael"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_Mi9T.elf"
	  type="ufs"
	  ;;
	"mi10lite_toco" )
	  NAME="Xiaomi Mi 10 Lite (Toco)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="toco"
	  firehosefile="prog_ufs_firehose_MiNote10Lite.elf"
	  type="ufs"
	  ;;
	"mi11tpro_vili" )
	  NAME="Xiaomi 11T Pro (Vili)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="vili"
	  firehosefile="prog_ufs_firehose_Mi11TProUFS.elf"
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
	"pocom2pro_gramin" )
	  NAME="Xiaomi Pocophone M2 Pro (Gramin)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="gramin"
	  firehosefile="prog_ufs_firehose_MiPocoM2Pro.elf"
	  type="ufs"
	  ;;
	"pocom3_citrus" )
	  NAME="Xiaomi Pocophone M3 (Citrus)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="citrus"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_MiPocoM3.elf"
	  type="ufs"
	  ;;
	"redmi5a_riva" )
	  NAME="Xiaomi Redmi 5A (Riva)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="riva"
	  firehosefile="prog_emmc_firehose_8953_ddr_xiaomi_redmi5a.mbn"
	  type="emmc"
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
	"redmi9t_lime" )
	  NAME="Xiaomi Redmi 9T (Lime)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="lime"
	  firehosefile="prog_ufs_firehose_sdm845_ddr_Mi9Power.elf"
	  type="ufs"
	  ;;
	"redmik20pro_raphael" )
	  NAME="Xiaomi Redmi K20 Pro (Raphael)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="raphael"
	  firehosefile="prog_ufs_firehose_RedmiK20Pro.elf"
	  type="ufs"
	  ;;
	"note5_whyred" )
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
	"note5a_ugglite" )
	  NAME="Xiaomi Redmi Note 5A (Ugglite)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="ugglite"
	  firehosefile="prog_emmc_firehose_8917_ddr_note5a_ugglite.mbn"
	  type="emmc"
	  ;;
	"note6pro_tulip" )
	  NAME="Xiaomi Redmi Note 6 Pro (Tulip)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="tulip"
	  firehosefile="prog_emmc_firehose_Sdm660_ddr_xiaomi_note6pro_tulip_s_rb4.elf"
	  type="emmc"
	  ;;
	"note8_ginkgo" )
	  NAME="Xiaomi Redmi Note 8 (Ginkgo)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="ginkgo"
	  firehosefile="prog_ufs_firehose_RedmiNote8.elf"
	  type="ufs"
	  ;;
	"note9s_curtana" )
	  NAME="Xiaomi Redmi Note 9S (Curtana)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="curtana"
	  firehosefile="prog_ufs_firehose_MiNote9s.elf"
	  type="ufs"
	  ;;
	"note9pro_joyeuse" )
	  NAME="Xiaomi Redmi Note 9 Pro (Joyeuse)"
	  BRAND="Xiaomi"
	  SHORT_BRAND="xiaomi"
	  DEVICE="joyeuse"
	  firehosefile="prog_ufs_firehose_MiNote9Pro.elf"
	  type="ufs"
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
	"--reboot-edl" | "-E" )
	  METHOD="edl"
	  METHOD_FULL="Reboot to EDL mode"
	  REBOOT_EDL=1
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
	[ -f "$PyQt_script" ] && {
		command -v python >/dev/null || {
			echo "Requirements:  python"
			exit 1
		}
		python -m pip list 2>&1 | grep "PyQt5.\s" >/dev/null || \
		python -m pip install PyQt5
		python "$PyQt_script"
		exit
	} || {
		echo "This is development release. Coming soon:  GUI window."
		exit 1
	}
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
if [ ! -z $REBOOT_EDL ]; then
	reboot_edl
	exit
fi
execution

for r in \
	$firehosefile boot.xml patch.xml \
	patch_mod.xml partition.xml
do rm "$TMPDIR/$r"
done

exit

## end_bash_scrip