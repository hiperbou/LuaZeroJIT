@rem Script to build LuaJIT (amalgamated, 64-bit, JIT enabled) with w64devkit (MinGW/GCC).
@rem Set W64DEVKIT_BIN to override the default w64devkit bin path.

@setlocal

@set W64DEVKIT_BIN=D:\hiperbou\w64devkit\w64devkit\bin
@set PATH=%W64DEVKIT_BIN%;%PATH%

@cd /d "%~dp0"
mingw32-make clean
mingw32-make amalg
@if errorlevel 1 goto :BAD

@echo.
@echo === Successfully built LuaJIT ===
@goto :END

:BAD
@echo.
@echo *******************************************************
@echo *** Build FAILED -- Please check the error messages ***
@echo *******************************************************
@exit /b 1

:END
@endlocal
