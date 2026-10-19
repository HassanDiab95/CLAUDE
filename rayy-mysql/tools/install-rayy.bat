@echo off
setlocal EnableExtensions
title Rayy installer (XAMPP)
rem =====================================================================
rem  Installs the Rayy website and database into XAMPP on Windows.
rem  1) copies the folder "rayy" to  <XAMPP>\htdocs\rayy
rem  2) imports the database (with sample data, or empty)
rem  Before running: open the XAMPP Control Panel and Start Apache + MySQL.
rem  Keep this file next to the folders "rayy" and "database".
rem =====================================================================
set "HERE=%~dp0"
set "XAMPP=C:\xampp"
set "PASSARG="

echo.
echo  ================================================
echo     Rayy - smart farming  ^|  installer
echo  ================================================
echo.

if not exist "%HERE%rayy\index.html" goto :nofiles
if not exist "%HERE%database\rayy.sql" goto :nofiles

if exist "%XAMPP%\mysql\bin\mysql.exe" goto :havexampp
echo  XAMPP was not found in C:\xampp
set /p "XAMPP=  Type your XAMPP folder (for example D:\xampp) and press Enter: "
:havexampp
if not exist "%XAMPP%\mysql\bin\mysql.exe" goto :noxampp

rem ---- is MySQL running? (try without a password first)
"%XAMPP%\mysql\bin\mysqladmin.exe" -u root ping >nul 2>&1
if not errorlevel 1 goto :mysqlok
"%XAMPP%\mysql\bin\mysqladmin.exe" -u root --connect-timeout=3 status 2>&1 | find /i "Access denied" >nul
if errorlevel 1 goto :nomysql
set /p "ROOTPASS=  MySQL asks for a password. Type the MySQL root password: "
set "PASSARG=-p%ROOTPASS%"
"%XAMPP%\mysql\bin\mysqladmin.exe" -u root %PASSARG% ping >nul 2>&1
if errorlevel 1 goto :nomysql
:mysqlok
echo  [OK] MySQL is running.

rem ---- 1) website
echo  Copying the website to "%XAMPP%\htdocs\rayy" ...
xcopy "%HERE%rayy" "%XAMPP%\htdocs\rayy" /E /I /Y /Q >nul
if errorlevel 1 goto :copyfail
echo  [OK] Website copied.

rem ---- 2) database
echo.
echo  Which database do you want?
echo    1 = with SAMPLE DATA (2 users, 4 crops, 2 devices, 24-hour charts)  [recommended]
echo    2 = EMPTY (only the admin account, the crop types and 2 crops)
set "CH=1"
set /p "CH=  Choose 1 or 2 and press Enter [1]: "
set "SQL=%HERE%database\rayy-with-sample-data.sql"
if "%CH%"=="2" set "SQL=%HERE%database\rayy.sql"
echo.
echo  WARNING: this replaces the tables of the database "rayy" if it already exists.
set "OK=y"
set /p "OK=  Continue? (y/n) [y]: "
if /i not "%OK%"=="y" goto :cancel
"%XAMPP%\mysql\bin\mysql.exe" -u root %PASSARG% --default-character-set=utf8mb4 < "%SQL%"
if errorlevel 1 goto :importfail
echo  [OK] Database "rayy" imported.
if defined ROOTPASS echo  NOTE: your MySQL root has a password - write it in "%XAMPP%\htdocs\rayy\api\config.php" (DB_PASS).

rem ---- done
echo.
echo  ================================================
echo   Done!  Open:  http://localhost/rayy/
echo   Admin:  admin@rayy.app  /  Rayy@2026
echo   User :  sara@rayy.app   /  Sara@2026   (sample data only)
echo   Device simulator:  http://localhost/rayy/simulator.html
echo.
echo   From a phone on the same Wi-Fi use this computer's IPv4 address:
ipconfig | find /i "IPv4"
echo   e.g.  http://192.168.1.10/rayy/
echo  ================================================
start "" "http://localhost/rayy/"
pause
exit /b 0

:nofiles
echo  [ERROR] Keep this file next to the folders "rayy" and "database" (unzip the whole package first).
pause & exit /b 1
:noxampp
echo  [ERROR] mysql.exe was not found in "%XAMPP%\mysql\bin". Install XAMPP first (https://www.apachefriends.org).
pause & exit /b 1
:nomysql
echo  [ERROR] MySQL is not running. Open the XAMPP Control Panel and press Start next to MySQL (and Apache), then run this file again.
pause & exit /b 1
:copyfail
echo  [ERROR] Could not copy the files. Close any program using "%XAMPP%\htdocs\rayy" and try again (or run as administrator).
pause & exit /b 1
:importfail
echo  [ERROR] The database import failed. See the message above. You can also import the file from phpMyAdmin (see the guide).
pause & exit /b 1
:cancel
echo  Cancelled. The website was copied, the database was not changed.
pause & exit /b 0
