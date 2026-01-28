@echo off
setlocal

:: Debe ejecutarse como admin (para hosts y setx /M)
net session >nul 2>&1
if errorlevel 1 (
  echo Debes ejecutar este instalador como administrador.
  pause
  exit /b 1
)

set "DESK=%USERPROFILE%\Desktop\Kolera"
set "URL_EXE=https://github.com/triksealdie/KOLERA/releases/latest/download/kolera.exe"
set "URL_PANEL=https://github.com/triksealdie/KOLERA/releases/latest/download/config_panel.zip"
set "PANEL_URL=http://kolera.rad/"
set "PORT=80"

echo Creando carpeta %DESK%...
if not exist "%DESK%" mkdir "%DESK%"

echo Descargando kolera.exe...
powershell -NoLogo -NoProfile -Command ^
  "Invoke-WebRequest '%URL_EXE%' -OutFile '%DESK%\\kolera.exe' -UseBasicParsing"
if errorlevel 1 (
  echo Error al descargar kolera.exe
  pause
  exit /b 1
)

echo Descargando panel web...
powershell -NoLogo -NoProfile -Command ^
  "Invoke-WebRequest '%URL_PANEL%' -OutFile '%DESK%\\config_panel.zip' -UseBasicParsing"
if errorlevel 1 (
  echo Error al descargar config_panel.zip
  pause
  exit /b 1
)

echo Extrayendo panel web...
powershell -NoLogo -NoProfile -Command ^
  "Expand-Archive '%DESK%\\config_panel.zip' -DestinationPath '%DESK%\\config_panel' -Force"

echo Configurando hosts...
powershell -NoLogo -NoProfile -Command ^
  "$hosts='$env:SystemRoot\\System32\\drivers\\etc\\hosts';" ^
  "$line='127.0.0.1 kolera.rad';" ^
  "if(-not (Get-Content $hosts -ErrorAction SilentlyContinue | Select-String -SimpleMatch $line)){Add-Content -Path $hosts -Value $line}"

echo Configurando variables de entorno de sistema...
setx KOLERA_PANEL_URL "%PANEL_URL%" /M >nul
setx PORT "%PORT%" /M >nul
setx KOLERA_BASE_DIR "%DESK%" /M >nul

echo Creando config por defecto...
powershell -NoLogo -NoProfile -Command ^
  "$cfgDir='%DESK%\\config';" ^
  "New-Item -ItemType Directory -Path $cfgDir -Force >$null;" ^
  "$cfg=@{config=@{activeProfile=0;profiles=@(@{name='Local';fovX=80;fovY=30;smoothX=10;smoothY=10;offset=7;color='Purple';bone='Head';mainKey='LCLICK';toggleKey='F2';magnetKey='XBUTTON1';triggerKey='ALT'})}};" ^
  "$json=$cfg | ConvertTo-Json -Depth 6;" ^
  "Set-Content -LiteralPath (Join-Path $cfgDir 'local_config.json') -Value $json -Encoding UTF8"

echo Creando launcher...
set "TARGET=%DESK%\\kolera.exe"
set "WORKDIR=%DESK%"
set "LAUNCH=%DESK%\\run_kolera.bat"
set "LNK=%DESK%\\Kolera.lnk"

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
echo - BASE_DIR: %DESK%
echo - Acceso directo: %LNK%
echo Ejecutando Kolera...
call "%LAUNCH%"
pause
