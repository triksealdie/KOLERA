@echo off
setlocal EnableDelayedExpansion

:: Auto-elevate si no es admin
net session >nul 2>&1
if errorlevel 1 (
  echo Solicitando permisos de administrador...
  powershell -NoLogo -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "BASE=%LOCALAPPDATA%\Kolera"
set "URL_EXE=https://github.com/triksealdie/KOLERA/releases/latest/download/kolera.exe"
set "URL_PANEL=https://github.com/triksealdie/KOLERA/releases/latest/download/config_panel.zip"
set "PANEL_URL=http://kolera.rad/"
set "PORT=80"
set /a TOTAL=6
set /a STEP=0

call :brand
call :step "Preparando directorio"
if not exist "%BASE%" mkdir "%BASE%"
attrib +h "%BASE%" 2>nul

call :step "Descargando ejecutable"
powershell -NoLogo -NoProfile -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$url='%URL_EXE%'; $out='%BASE%\\kolera.exe';" ^
  "for($i=0;$i -lt 4;$i++){try{Invoke-WebRequest $url -OutFile $out -UseBasicParsing -ErrorAction Stop; exit 0}catch{Start-Sleep -Seconds 3}}; exit 1"
if errorlevel 1 goto :fail

call :step "Descargando panel"
powershell -NoLogo -NoProfile -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$url='%URL_PANEL%'; $out='%BASE%\\config_panel.zip';" ^
  "for($i=0;$i -lt 4;$i++){try{Invoke-WebRequest $url -OutFile $out -UseBasicParsing -ErrorAction Stop; exit 0}catch{Start-Sleep -Seconds 3}}; exit 1"
if errorlevel 1 goto :fail

call :step "Descomprimiendo panel"
powershell -NoLogo -NoProfile -Command ^
  "Expand-Archive '%BASE%\\config_panel.zip' -DestinationPath '%BASE%\\config_panel' -Force"
del "%BASE%\\config_panel.zip" 2>nul

call :step "Aplicando sistema"
powershell -NoLogo -NoProfile -Command ^
  "$hosts=[IO.Path]::Combine($env:SystemRoot,'System32','drivers','etc','hosts');" ^
  "$line='127.0.0.1 kolera.rad';" ^
  "if(-not (Get-Content $hosts -ErrorAction SilentlyContinue | Select-String -SimpleMatch $line)){Add-Content -Path $hosts -Value $line}"
setx KOLERA_PANEL_URL "%PANEL_URL%" /M >nul
setx PORT "%PORT%" /M >nul
setx KOLERA_BASE_DIR "%BASE%" /M >nul

call :step "Creando config y accesos"
powershell -NoLogo -NoProfile -Command ^
  "$cfgDir='%BASE%\\config';" ^
  "New-Item -ItemType Directory -Path $cfgDir -Force >$null;" ^
  "$cfg=@{config=@{activeProfile=0;profiles=@(@{name='Local';fovX=80;fovY=30;smoothX=10;smoothY=10;offset=7;color='Purple';bone='Head';mainKey='LCLICK';toggleKey='F2';magnetKey='XBUTTON1';triggerKey='ALT'})}};" ^
  "$json=$cfg | ConvertTo-Json -Depth 6;" ^
  "Set-Content -LiteralPath (Join-Path $cfgDir 'local_config.json') -Value $json -Encoding UTF8"

set "TARGET=%BASE%\\kolera.exe"
set "WORKDIR=%BASE%"
set "LAUNCH=%BASE%\\run_kolera.bat"
set "LNK=%USERPROFILE%\\Desktop\\Kolera.lnk"

(
  echo @echo off
  echo setlocal
  echo set KOLERA_PANEL_URL=%PANEL_URL%
  echo set PORT=%PORT%
  echo set KOLERA_BASE_DIR=%WORKDIR%
  echo echo BASE_DIR: %%KOLERA_BASE_DIR%%
  echo echo PANEL: %%KOLERA_PANEL_URL%%  PORT: %%PORT%%
  echo cd /d "%WORKDIR%"
  echo powershell -NoLogo -NoProfile -Command "Start-Process -FilePath 'kolera.exe' -WorkingDirectory '%WORKDIR%' -Verb RunAs"
) > "%LAUNCH%"

powershell -NoLogo -NoProfile -Command ^
  "$shell=New-Object -ComObject WScript.Shell;" ^
  "$lnk=$shell.CreateShortcut('%LNK%');" ^
  "$lnk.TargetPath='%LAUNCH%';" ^
  "$lnk.WorkingDirectory='%WORKDIR%';" ^
  "$lnk.IconLocation='%TARGET%,0';" ^
  "$lnk.Save();"

call :step "Listo"

echo.
echo Instalacion completada. Se lanzara Kolera...
timeout /t 2 >nul
start "" "%LAUNCH%"
echo.
echo Presiona una tecla para cerrar esta ventana cuando confirmes que Kolera abrio bien.
pause
exit /b 0

:fail
echo.
echo [X] Error descargando. Revisa tu conexion o GitHub.
pause
exit /b 1

:step
set /a STEP+=1
set "MSG=%~1"
set /a PCT=STEP*100/TOTAL
set "BAR===================="
set "SPACE                    "
set /a FILL=STEP*20/TOTAL
set /a GAP=20-FILL
set "OUT=[!BAR:~0,%FILL%!!SPACE:~0,%GAP%!]^| !PCT!%%    !MSG!"
cls
call :brand
echo !OUT!
echo.
goto :eof

:brand
echo.
echo  _  __     ___      ___  _____  ____    _       
echo ^| ^|/ /__ _/ _ ^|__  / _ \\^|_   _^|/ ___^|  (_) ___  
echo ^| ' // _` ^| ^| ^| \\ \\/ /_)/ ^|^| ^|  ^| \\___ \\  ^| ^|/ _ \\ 
echo ^| . \\ (_^| ^| ^|_^| |>  < ___/^|^| ^|__^| ^|___) ^| ^| ^| (_) ^
echo ^|_^|\\_\\__,_^|\\___//_/\\_\\    ^|_____^|^|____/^|_^|_^|\\___/ 
echo             Instalador Kolera
echo.
goto :eof
