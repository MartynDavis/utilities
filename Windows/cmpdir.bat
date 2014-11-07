@echo off

    setlocal ENABLEDELAYEDEXPANSION
    
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
    if not "%~3" == "" goto usage
    if "%~1" == "" goto usage
    
    set _THIS_DIR=%~dpnx1
    set _THAT_DIR=%~dpnx2
    set _THIS_EXTRA=0
    set _THAT_EXTRA=0
    
    if "%_THIS_DIR%" == "%_THAT_DIR%" (
        echo.
        echo FAIL: Please specify different folders.
        echo.
        exit /B 1
    )
    
    if not exist "%_THIS_DIR%\." (
        echo.
        echo FAIL: Folder "%_THIS_DIR%" does not exist.
        echo.
        exit /B 1
    )
    
    if not exist "%_THAT_DIR%\." (
        echo.
        echo FAIL: Folder "%_THAT_DIR%" does not exist.
        echo.
        exit /B 1
    )
    echo.
    echo Comparing files in "%_THIS_DIR%" and "%_THAT_DIR%"
    
    pushd %_THIS_DIR%
    for %%f in (*) do (
        if not exist "%_THAT_DIR%\%%f" (
            if "!_THIS_EXTRA!" == "0" (
                echo.
                echo Extra files in %_THIS_DIR%
                echo ----------------------
            )
            echo   %%f
            set /A _THIS_EXTRA=_THIS_EXTRA+1
        )
    )
    if not "%_THIS_EXTRA%" == "0" (
        echo ----------------------
        echo Files: %_THIS_EXTRA%
    )
    popd

    pushd %_THAT_DIR%
    for %%f in (*) do (
        if not exist "%_THIS_DIR%\%%f" (
            if "!_THAT_EXTRA!" == "0" (
                echo.
                echo Extra files in %_THAT_DIR%
                echo ----------------------
            )
            echo   %%f
            set /A _THAT_EXTRA=_THAT_EXTRA+1
        )
    )
    if not "%_THAT_EXTRA%" == "0" (
        echo ----------------------
        echo Files: %_THAT_EXTRA%
    )
    popd
    
    echo.
    echo Extra files in '%_THIS_DIR%': %_THIS_EXTRA%
    echo Extra files in '%_THAT_DIR%': %_THAT_EXTRA%
    echo.
    goto exit
    
:usage
    echo.
    echo usage: %_THIS% this that
    echo.
    echo        Compares the folder 'this' with the folder 'that' and shows which files
    echo        are missing or added.
    echo.
    echo        NOTE: File contents are not compared, just file existence.
    echo.
    goto exit

:exit
    endlocal
