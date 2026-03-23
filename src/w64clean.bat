@rem Hard-clean all build artifacts from src/ and src/host/.
@rem Use this before a build to guarantee a fresh compile.
@rem Must be run from the src/ directory (or called via the build scripts which cd there).

@setlocal
@cd /d "%~dp0"

@echo Cleaning src/ build artifacts...
@del /f /q luajit.exe 2>nul
@del /f /q lua51.dll 2>nul
@del /f /q libluajit.a 2>nul
@del /f /q libluajit-5.1.dll.a 2>nul
@del /f /q ljamalg.o 2>nul
@del /f /q *.o 2>nul
@del /f /q *.obj 2>nul
@del /f /q *.lib 2>nul
@del /f /q *.exp 2>nul
@del /f /q *.dll 2>nul
@del /f /q *.exe 2>nul
@del /f /q *.manifest 2>nul
@del /f /q *.pdb 2>nul
@del /f /q *.ilk 2>nul
@del /f /q lj_vm.S 2>nul
@del /f /q lj_bcdef.h 2>nul
@del /f /q lj_ffdef.h 2>nul
@del /f /q lj_libdef.h 2>nul
@del /f /q lj_recdef.h 2>nul
@del /f /q lj_folddef.h 2>nul
@del /f /q luajit.h 2>nul
@del /f /q luajit_relver.txt 2>nul

@echo Cleaning src/host/ build artifacts...
@del /f /q host\minilua.exe 2>nul
@del /f /q host\buildvm.exe 2>nul
@del /f /q host\buildvm_arch.h 2>nul
@del /f /q host\*.o 2>nul
@del /f /q host\*.obj 2>nul
@del /f /q host\*.exe 2>nul

@echo Cleaning src/jit/ generated files...
@del /f /q jit\vmdef.lua 2>nul

@echo Clean done.
@endlocal
