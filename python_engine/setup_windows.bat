@echo off
setlocal
cd /d "%~dp0"

set "PY_LAUNCHER="
py -3.12 --version >nul 2>&1 && set "PY_LAUNCHER=py -3.12"
if not defined PY_LAUNCHER py -3.11 --version >nul 2>&1 && set "PY_LAUNCHER=py -3.11"
if not defined PY_LAUNCHER py -3.13 --version >nul 2>&1 && set "PY_LAUNCHER=py -3.13"
if not defined PY_LAUNCHER py -3.10 --version >nul 2>&1 && set "PY_LAUNCHER=py -3.10"

if not defined PY_LAUNCHER (
  echo Python 3.10, 3.11, 3.12, or 3.13 (64-bit) was not found.
  echo Install Python from https://www.python.org/downloads/windows/
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo Creating the Grad-CAM Python environment...
  %PY_LAUNCHER% -m venv .venv
  if errorlevel 1 goto :error
)

echo Installing Grad-CAM dependencies. The first installation needs internet.
".venv\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 goto :error
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto :error

echo.
echo Verifying TensorFlow...
".venv\Scripts\python.exe" -c "import tensorflow as tf; print('TensorFlow', tf.__version__)"
if errorlevel 1 goto :error

echo.
echo Grad-CAM environment is ready.
echo Copy each specialist Keras file to models\<specialist_model_name>.keras
pause
exit /b 0

:error
echo.
echo Grad-CAM setup failed. Review the error shown above.
pause
exit /b 1
