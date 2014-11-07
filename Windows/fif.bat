@echo off

    setlocal
    
    set _THIS=%~nx0
    set _FIND2_ARGS=/v
    set _FIND3_ARGS=
    set _FIF_MODE=0
    
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
    if /i "%_ARG%" == "0" (
        set _FIND2_ARGS=
        goto processArgs
    )
    if /i "%_ARG%" == "l" (
        set _FIF_MODE=1
        goto processArgs
    )
    if /i "%_ARG%" == "n" (
        set _FIND3_ARGS=/n %_FIND3_ARGS%
        goto processArgs
    )
    if /i "%_ARG%" == "v" (
        set _FIND3_ARGS=/v %_FIND3_ARGS%
        goto processArgs
    )
    echo.
    echo FAIL: Unknown command line option '%_ARG_ORIGINAL%' specified.
    goto usage

:start
    if "%~1" == "" goto usage
    set _PATTERN=%~1
    shift
    
    if     "%_FIF_MODE%" == "0" find /c /i "%_PATTERN%" %1 %2 %3 %4 %5 %6 %7 %8 %9 | find "---" | find %_FIND2_ARGS% ": 0"
    if not "%_FIF_MODE%" == "0" find %_FIND3_ARGS% /i "%_PATTERN%" %1 %2 %3 %4 %5 %6 %7 %8 %9
    goto exit
    
:usage
    echo.
    echo usage: %_THIS% [-0] [-l] [-n] [-v] pattern file ...
    echo.
    echo        -0  Show files which do not contain this string
    echo        -l  List matches within individual files ^(i.e. do not count matches^)
    echo        -n  Show line numbers ^(if listing matches^)
    echo        -v  Show lines which do not match pattern ^(if listing matches^)
    echo.
    echo        Finds files which contain at least one occurance of the specified string
    exit /B 1
    
:exit
    endlocal
