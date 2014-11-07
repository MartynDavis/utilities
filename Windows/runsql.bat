@echo off

    rem
    rem Allows a SQL file to be run against the specified database.
    rem If the RUNSQL_DATABASE environment variable is defined, this value is
    rem is used as the database to invoke the SQL against if not specified on the 
    rem command line.
    rem
    rem If output file is not specified, then the SQL input file with the extension ".out"
    rem is used.
    rem
    rem This batch file invoked SQLCMD with the following parameters:
    rem
    rem     -b      Set errorlevel on exit
    rem     -e      Echo SQL
    rem     -k1     Replace CR, LF and TAB characters with a single space
    rem     -s"	"   Use TAB as the column delimiter (do not replace the TAB character within the double quotes)
    rem     -W      Remove trailing spaces (greatly reduces output size)
    rem

    setlocal ENABLEDELAYEDEXPANSION

    set _THIS=%~nx0
    set _DATABASE=%RUNSQL_DATABASE%
    set _INPUT=
    set _OUTPUT=
    set _START=
    set _END=

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
    if /i "%_ARG%" == "d" (
        if "%~1" == "" goto usage
        set _DATABASE=%~1
        shift
        goto processArgs
    )
    echo.
    echo FAIL: Unknown command line option '%_ARG_ORIGINAL%' specified.
    goto usage

:start
    
    if "%~1" == "" goto usage
    if not "%~3" == "" goto usage
    
    if "%_DATABASE%" == "" goto noDatabase
    
    set _INPUT=%~1
    set _OUTPUT=%~2
    
    if not exist "%_INPUT%" goto errorNoInput
    
    if "%_OUTPUT%" == "" set _OUTPUT=%~n1.out
    
    if /i "%_OUTPUT%" == "%_INPUT%" (
        echo.
        echo Output file "%_OUTPUT%" is the same as the input file "%_INPUT%".
        echo Please explicitly specify a different file name for the output.
        echo.
        goto exit
    )
    
    if exist "%_OUTPUT%" (del "%_OUTPUT%") || (goto errorDelOutput)
    
    echo.
    echo Database: %_DATABASE%
    echo Input:    %_INPUT%
    echo Output:   %_OUTPUT%
    echo.
    
    set _RETCODE=0
    set _SQLARGS=
    
    if not "%_DATABASE%" == "" set _SQLARGS=%_SQLARGS% -d "%_DATABASE%"
    
    set _START=%TIME%
    echo SQLCMD Start:       %_START%
    
    sqlcmd -b -e -k1 -s"	" -W %_SQLARGS% -i "%_INPUT%" -o "%_OUTPUT%"
    
    set _RETCODE=%ERRORLEVEL%
    set _END=%TIME%
    
    echo SQLCMD End:         %_END%
    echo SQLCMD Return Code: %_RETCODE%
    
    echo SQLCMD Start:       %_START% >> "%_OUTPUT%"
    echo SQLCMD End:         %_END% >> "%_OUTPUT%"
    echo SQLCMD Return Code: %_RETCODE% >> "%_OUTPUT%"
    
    goto exit

:noDatabase
    echo.
    echo Error: No database has been specified.
    echo.
    echo Please use "-d database" or set the RUNSQL_DATABASE environment variable.
    echo.
    goto exit

:usage
    echo.
    echo Usage: %_THIS% [-d database] input [output]
    echo.
    echo.       Default database is taken from RUNSQL_DATABASE environment variable.
    echo.
    exit /B 1

:errorNoInput
    echo.
    echo Error: Input file "%_INPUT%" does not exist
    echo.
    goto exit

:errorDelOutput
    echo.
    echo Error: Can't delete existing output file "%_OUTPUT%"
    echo.
    goto exit

:exit

    if not "%_RETCODE%" == "" exit /B %_RETCODE%
    endlocal
