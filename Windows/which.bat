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
    if "%~1" == "" goto usage
    set _WHICH=%~$PATH:1
    if "%_WHICH%" == "" echo %~1 - Not found!
    if not "%_WHICH%" == "" echo %~1 - %_WHICH%
    
    shift
    if "%~1" == "" goto exit
    goto start

:usage
    echo.
    echo usage: %_THIS% file...
    echo.
    echo Displays where on the path the file is located.
    echo.
    echo NOTE: Executable extensions, '.exe', '.bat' or '.cmd', must be specified.
    echo.
    exit /B 1

:exit
    endlocal
