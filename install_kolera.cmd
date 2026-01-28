@echo off
setlocal

:: Comprueba permisos de administrador
net session >nul 2>&1
if errorlevel 1 (
  echo Debes ejecutar este instalador como administrador.
  pause
  exit /b 1
)

set PANEL_URL=http://kolera.rad/
set PORT=80

echo Configurando variables de entorno de sistema...
setx KOLERA_PANEL_URL "%PANEL_URL%" /M >nul
setx PORT "%PORT%" /M >nul

echo Asegurando entrada en hosts...
powershell -NoLogo -NoProfile -Command ^
  "$hosts='$env:SystemRoot\System32\drivers\etc\hosts';" ^
  "$line='127.0.0.1 kolera.rad';" ^
  "if(-not (Get-Content $hosts -ErrorAction SilentlyContinue | Select-String -SimpleMatch $line)){Add-Content -Path $hosts -Value $line}"

echo Preparando carpeta en el escritorio...
set "DESK=%USERPROFILE%\Desktop\Kolera"
if not exist "%DESK%" mkdir "%DESK%"

echo Configurando KOLERA_BASE_DIR en %DESK%...
setx KOLERA_BASE_DIR "%DESK%" /M >nul

echo Copiando kolera.exe a la carpeta del escritorio...
powershell -NoLogo -NoProfile -Command ^
  "Copy-Item -Path '%~dp0kolera.exe' -Destination '%DESK%\\kolera.exe' -Force"

echo Copiando panel web (config_panel)...
powershell -NoLogo -NoProfile -Command ^
  "if (Test-Path '%~dp0config_panel') { Copy-Item -Path '%~dp0config_panel' -Destination '%DESK%' -Recurse -Force } else { throw 'No se encontró config_panel junto al instalador'; }"
if errorlevel 1 (
  echo Error: no se pudo copiar config_panel. Asegurate de colocar la carpeta junto a install_kolera.cmd y kolera.exe.
  pause
  exit /b 1
)

echo Replicando carpeta config (si existe) o creando una por defecto...
if exist "%~dp0config" (
  powershell -NoLogo -NoProfile -Command ^
    "Copy-Item -Path '%~dp0config' -Destination '%DESK%' -Recurse -Force"
) else (
  powershell -NoLogo -NoProfile -Command ^
    "$cfgDir='%DESK%\\config';" ^
    "New-Item -ItemType Directory -Path $cfgDir -Force >$null;" ^
    "$cfg=@{config=@{activeProfile=0;profiles=@(@{name='Local';fovX=80;fovY=30;smoothX=10;smoothY=10;offset=7;color='Purple';bone='Head';mainKey='LCLICK';toggleKey='F2';magnetKey='XBUTTON1';triggerKey='ALT'})}};" ^
    "$json=$cfg | ConvertTo-Json -Depth 6;" ^
    "Set-Content -LiteralPath (Join-Path $cfgDir 'local_config.json') -Value $json -Encoding UTF8"
)
if errorlevel 1 (
  echo Error al preparar la carpeta config en %DESK%.
  pause
  exit /b 1
)

echo Creando launcher y acceso directo dentro de la carpeta...
set "TARGET=%DESK%\kolera.exe"
set "WORKDIR=%DESK%"
set "LAUNCH=%DESK%\run_kolera.bat"
set "LNK=%DESK%\Kolera.lnk"

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
echo - Variables: KOLERA_PANEL_URL=%PANEL_URL%  PORT=%PORT%
echo - Hosts: 127.0.0.1 kolera.rad
echo - Acceso directo: %LNK%
echo.
echo Usa el acceso directo "Kolera" para lanzar el exe siempre con la configuracion correcta.
pause
