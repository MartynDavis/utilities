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
    if not "%~1" == "" goto usage
    endlocal
    echo Copying '%CD%' to clipboard...
    echo %CD% | clip 
    goto exit
    
:usage
    echo.
    echo usage: %_THIS%
    echo.
    echo        Copies the current directory to the clipboard
    exit /B 1
    
:exit
