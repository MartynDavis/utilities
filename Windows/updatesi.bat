@echo off

    rem
    rem Updates SysInternals utilities to the c:\bin folder, using robocopy.
    rem Uses WebDAV, and as such requires that the WebClient service to be active.
    rem If WebClient service is not active, the script will start and stop the service,
    rem in which case, administrative privileges are required.
    rem

    setlocal

    set SERVICE=WebClient
    set STARTED=0
    set SOURCE=\\live.sysinternals.com\tools
    set DEST=c:\bin

    echo Checking whether %SERVICE% service is active
    (sc query %SERVICE% | find " STATE " | find " 4  RUNNING" > nul:) || (goto start)
    echo %SERVICE% service is already active
    goto update
    
:start
    echo Starting %SERVICE% service...
    (net start %SERVICE%) || (goto errorStartWebClient)
    set STARTED=1
    goto update

:update
    echo Coying latest files from "%SOURCE%" to "%DEST%"...
    robocopy "%SOURCE%" "%DEST%" /R:0 /S /XF Thumbs.db /XX %1 %2 %3 %4 %5 %6 %7 %8 %9
    if not errorlevel 16 goto stop

    echo.
    echo Unable to copy files from "%SOURCE%" to "%DEST%"
    echo.
    goto stop

:stop
    if "%STARTED%" == "0" goto exit
    
    echo Stopping %SERVICE% service...
    (net stop %SERVICE%) || (goto errorStopWebClient)

    goto exit

:errorStartWebClient
    echo.
    echo Unable to start %SERVICE% service - Make sure you are have administrator privileges.
    echo.
    goto exit

:errorStopWebClient
    echo.
    echo Unable to stop %SERVICE% service.
    echo.
    goto exit

:exit

    endlocal
