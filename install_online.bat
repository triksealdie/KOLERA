@echo off
setlocal

:: Debe ejecutarse como admin (para hosts y setx /M)
net session >nul 2>&1
if errorlevel 1 (
  echo Debes ejecutar este instalador como administrador.
  pause
  exit /b 1
)

:: Carpeta oculta donde se almacenará todo
set "BASE=%LOCALAPPDATA%\Kolera"
set "URL_EXE=https://github.com/triksealdie/KOLERA/releases/latest/download/kolera.exe"
set "URL_PANEL=https://github.com/triksealdie/KOLERA/releases/latest/download/config_panel.zip"
set "PANEL_URL=http://kolera.rad/"
set "PORT=80"

echo Creando carpeta oculta en %BASE%...
if not exist "%BASE%" mkdir "%BASE%"
attrib +h "%BASE%" 2>nul

echo Descargando kolera.exe...
powershell -NoLogo -NoProfile -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$url='%URL_EXE%'; $out='%BASE%\\kolera.exe';" ^
  "for($i=0;$i -lt 4;$i++){try{Invoke-WebRequest $url -OutFile $out -UseBasicParsing -ErrorAction Stop; exit 0}catch{Start-Sleep -Seconds 3}}; exit 1"
if errorlevel 1 (
  echo Error al descargar kolera.exe
  pause
  exit /b 1
)

echo Descargando panel web...
powershell -NoLogo -NoProfile -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$url='%URL_PANEL%'; $out='%BASE%\\config_panel.zip';" ^
  "for($i=0;$i -lt 4;$i++){try{Invoke-WebRequest $url -OutFile $out -UseBasicParsing -ErrorAction Stop; exit 0}catch{Start-Sleep -Seconds 3}}; exit 1"
if errorlevel 1 (
  echo Error al descargar config_panel.zip
  pause
  exit /b 1
)

echo Extrayendo panel web...
powershell -NoLogo -NoProfile -Command ^
  "Expand-Archive '%BASE%\\config_panel.zip' -DestinationPath '%BASE%\\config_panel' -Force"
del "%BASE%\\config_panel.zip" 2>nul

echo Configurando hosts...
powershell -NoLogo -NoProfile -Command ^
  "$hosts=[IO.Path]::Combine($env:SystemRoot,'System32','drivers','etc','hosts');" ^
  "$line='127.0.0.1 kolera.rad';" ^
  "if(-not (Get-Content $hosts -ErrorAction SilentlyContinue | Select-String -SimpleMatch $line)){Add-Content -Path $hosts -Value $line}"

echo Configurando variables de entorno de sistema...
setx KOLERA_PANEL_URL "%PANEL_URL%" /M >nul
setx PORT "%PORT%" /M >nul
setx KOLERA_BASE_DIR "%BASE%" /M >nul

echo Creando config por defecto...
powershell -NoLogo -NoProfile -Command ^
  "$cfgDir='%BASE%\\config';" ^
  "New-Item -ItemType Directory -Path $cfgDir -Force >$null;" ^
  "$cfg=@{config=@{activeProfile=0;profiles=@(@{name='Local';fovX=80;fovY=30;smoothX=10;smoothY=10;offset=7;color='Purple';bone='Head';mainKey='LCLICK';toggleKey='F2';magnetKey='XBUTTON1';triggerKey='ALT'})}};" ^
  "$json=$cfg | ConvertTo-Json -Depth 6;" ^
  "Set-Content -LiteralPath (Join-Path $cfgDir 'local_config.json') -Value $json -Encoding UTF8"

echo Creando launcher...
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

echo Listo.
echo - Descargas desde: %URL_EXE% y %URL_PANEL%
echo - BASE_DIR (oculto): %BASE%
echo - Acceso directo en escritorio: %LNK%
echo Ejecutando Kolera...
call "%LAUNCH%"
pause
