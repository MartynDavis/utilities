@echo off

    setlocal

    set _THIS=%~nx0

:processArgs
    set _ARG=%~1
    if "%_ARG:~0,1%" == "-" (
        set _ARG=%_ARG:~1%
        set _ARG_ORIGINAL=%_ARG%
    ) else (
        if "%_ARG:~0,1%" == "/" (
            set _ARG=%_ARG:~1%
            set _ARG_ORIGINAL=%_ARG%
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
    
:usage
    echo.
    echo usage: %_THIS% [time_t]
    echo.
    echo        Displays the local and GMT times for the associated Unix time time_t.
    echo.
    echo        NOTE: Requires the use of perl.
    echo.
    exit /B 1
    
:start
    if not "%~2" == "" goto usage
    echo.
    if     "%~1" == "" perl -e "$x = time();print 'Time:  ' . $x . """"\n"""";print 'Local: ' . scalar localtime($x) . """"\n"""";print 'GMT:   ' . scalar gmtime($x)    . """"\n"""";"
    if not "%~1" == "" perl -e "$x = %~1   ;print 'Time:  ' . $x . """"\n"""";print 'Local: ' . scalar localtime($x) . """"\n"""";print 'GMT:   ' . scalar gmtime($x)    . """"\n"""";"

    endlocal
