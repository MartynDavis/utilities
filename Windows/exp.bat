@echo off
    setlocal
    
    set _THIS=%~nx0

:processArgs
    set _ARG=%~1
    if "%_ARG:~0,1%" == "-" (
        set _ARG_ORIGINAL=%_ARG%
        set _ARG=%_ARG:~1%
    ) else (
        if "%_ARG:~0,1%" == "/" (
            set _ARG_ORIGINAL=%_ARG%
            set _ARG=%_ARG:~1%
        ) else (
            goto start
        )
    )
    shift
    if /i "%_ARG%" == "help" goto usage
    if /i "%_ARG%" == "-help" goto usage
    if /i "%_ARG%" == "?" goto usage
    echo.
    echo FAIL: Unknown command line option '%_ARG_ORIGINAL%' specified.
    goto usage

:start
    if not "%~2" == "" goto usage
    if "%~1" == "" start explorer .
    if not "%~1" == "" start explorer "%~1"
    goto exit
    
:usage
    echo.
    echo usage: %_THIS% [folder]
    echo.
    echo        Opens Windows Explorer on specified folder, or current folder if no folder specified.
    echo.
    exit /B 1
    
:exit
    endlocal
