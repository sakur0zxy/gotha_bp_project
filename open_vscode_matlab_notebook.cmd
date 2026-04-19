@echo off
setlocal

set "PROJECT_ROOT=%~dp0"
if "%PROJECT_ROOT:~-1%"=="\" set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
for %%I in ("%PROJECT_ROOT%\..") do set "WORKSPACE_ROOT=%%~fI"
set "PY_SCRIPTS=C:\Users\zxy\AppData\Roaming\Python\Python313\Scripts"
set "PY_HOME=C:\Users\zxy\AppData\Roaming\Python\Python313"
set "KERNEL_HOME=C:\Users\zxy\AppData\Local\Temp\codex_home"
set "JUPYTER_DATA_DIR=%WORKSPACE_ROOT%\.jupyter_local"
set "JUPYTER_CONFIG_DIR=%WORKSPACE_ROOT%\.jupyter_local\config"
set "IPYTHONDIR=%WORKSPACE_ROOT%\.ipython_local"
set "JUPYTER_RUNTIME_DIR=C:\Users\zxy\AppData\Local\Temp\codex_jupyter_runtime"

if not exist "%JUPYTER_DATA_DIR%" mkdir "%JUPYTER_DATA_DIR%"
if not exist "%JUPYTER_CONFIG_DIR%" mkdir "%JUPYTER_CONFIG_DIR%"
if not exist "%IPYTHONDIR%" mkdir "%IPYTHONDIR%"
if not exist "%JUPYTER_RUNTIME_DIR%" mkdir "%JUPYTER_RUNTIME_DIR%"
if not exist "%KERNEL_HOME%" mkdir "%KERNEL_HOME%"
if not exist "%KERNEL_HOME%\.matlab" mkdir "%KERNEL_HOME%\.matlab"

set "JUPYTER_ALLOW_INSECURE_WRITES=true"
set "HOME=%KERNEL_HOME%"
set "USERPROFILE=%KERNEL_HOME%"
set "HOMEDRIVE=C:"
set "HOMEPATH=\Users\zxy\AppData\Local\Temp\codex_home"
set "MWI_USE_EXISTING_LICENSE=true"
set "MWI_CUSTOM_MATLAB_ROOT=E:\Program Files (x86)\Matlab\R2022b"
set "PATH=%PY_SCRIPTS%;%PY_HOME%;%PATH%"

code "%PROJECT_ROOT%\main_gotha_bp.ipynb"
