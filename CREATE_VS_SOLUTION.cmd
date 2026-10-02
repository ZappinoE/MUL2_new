@echo off
rem Generates (or refreshes) the Visual Studio solution BUILD\WINDOWS_IFX\MUL2_V3.sln.
rem CMake stays the single source of truth; never edit the .sln/.vfproj by hand.
rem Usage: CREATE_VS_SOLUTION.cmd [open] [build]
setlocal
cd /d "%~dp0"
if not defined ONEAPI_ROOT set "ONEAPI_ROOT=C:\Program Files (x86)\Intel\oneAPI"
call "%ONEAPI_ROOT%\setvars.bat" intel64 >nul 2>&1
cmake --preset windows-ifx
if errorlevel 1 (
  echo CMake configuration failed.
  exit /b 1
)
echo Solution: %~dp0BUILD\WINDOWS_IFX\MUL2_V3.sln
if /i "%~1"=="build" cmake --build BUILD/WINDOWS_IFX --config Release
if /i "%~1"=="open" start "" "%~dp0BUILD\WINDOWS_IFX\MUL2_V3.sln"
if /i "%~2"=="open" start "" "%~dp0BUILD\WINDOWS_IFX\MUL2_V3.sln"
endlocal