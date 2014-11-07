@echo off

    rem
    rem Updates SysInternals utilities to the folder, using robocopy.
    rem Uses WebDAV, and as such requires that the WebClient service to be active.
    rem If WebClient service is not active, the script will start and stop the service,
    rem in which case, administrative privileges are required.
    rem

    setlocal

    set _THIS=%~nx0
    set _FOLDER_DEFAULT=c:\bin
    set _FOLDER=%UPDATESI_FOLDER%
    if "%_FOLDER%" == "" set _FOLDER=%_FOLDER_DEFAULT%

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
    if /i "%_ARG%" == "f" (
        if "%~1" == "" goto usage
        set _FOLDER=%~dpnx1
        shift
        goto processArgs
    )
    echo.
    echo FAIL: Unknown command line option '%_ARG_ORIGINAL%' specified.
    goto usage

:start
    set _SERVICE=WebClient
    set _STARTED=0
    set _SOURCE=\\live.sysinternals.com\tools
    
    if not "%~1" == "" goto usage
    
    if not exist "%_FOLDER%\." (
        echo.
        echo FAIL: The folder '%_FOLDER%' does not exist.
        echo.
        exit /B 1
    )

    echo Checking whether %_SERVICE% service is active
    (sc query %_SERVICE% | find " STATE " | find " 4  RUNNING" > nul:) || (goto startService)
    echo %_SERVICE% service is already active
    goto update
    
:startService
    echo Starting %_SERVICE% service...
    (net start %_SERVICE%) || (goto errorStartWebClient)
    set _STARTED=1
    goto update

:update
    echo Coying latest files from "%_SOURCE%" to "%_FOLDER%"...
    robocopy "%_SOURCE%" "%_FOLDER%" /R:0 /S /XF Thumbs.db About_This_Site.txt readme.txt Eula.txt /XX %1 %2 %3 %4 %5 %6 %7 %8 %9
    if not errorlevel 16 goto stopService

    echo.
    echo Unable to copy files from "%_SOURCE%" to "%_FOLDER%"
    echo.
    goto stopService

:stopService
    if "%_STARTED%" == "0" goto exit
    
    echo Stopping %_SERVICE% service...
    (net stop %_SERVICE%) || (goto errorStopWebClient)

    goto exit

:errorStartWebClient
    echo.
    echo Unable to start %_SERVICE% service - Make sure you are have administrator privileges.
    echo.
    goto exit

:errorStopWebClient
    echo.
    echo Unable to stop %_SERVICE% service.
    echo.
    goto exit

:usage
    echo.
    echo usage: %_THIS% [-f folder]
    echo.
    echo        Updates SysInternals utilities using robocopy.
    echo.
    echo        -f folder Update the files in the specified folder ^(default: %_FOLDER_DEFAULT%^)
    echo.
    echo        Automatically starts 'WebClient' service if this is not already active,
    echo        in which case administrative privileges are required.
    echo.
    exit /B 1

:exit

    endlocal
