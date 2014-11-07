@echo off
    
    rem Synchronizes the changes from upstream repositories (can be overridden)
    rem
    rem Source: https://help.github.com/articles/syncing-a-fork/
    
    setlocal ENABLEDELAYEDEXPANSION
    
    set _THIS=%~nx0
    set _GS_REMOTE_DEFAULT=upstream
    
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
    echo usage: %_THIS% [branch [remote]]
    echo.
    echo        branch - Branch to synchronize to ^(default is currently selected branch^)
    echo        remote - Remote to synchronize from ^(default is "%_GS_REMOTE_DEFAULT%"^)
    echo.
    exit /B 1
    
:start
    if not "%~3" == "" goto usage
    set _GS_BRANCH=%~1
    rem NOTE: if branch is not specified, then we accept the currently selected branch
    set _GS_REMOTE=%~2
    if "%_GS_REMOTE%" == "" set _GS_REMOTE=%_GS_REMOTE_DEFAULT%
    
    if not exist ".git" (
        echo.
        echo FAIL: Current folder does not belong to a git repository
        echo.
        exit /B 1
    )
    
    echo.
    echo Syncing checking with '%_GS_REMOTE%' repository
    echo.
    
    set _GS_VALID=0
    echo Checking remotes...
    for /F "tokens=1-4 delims= " %%A in ('git remote show') do (
        if "%%A" == "!_GS_REMOTE!" (
            set _GS_VALID=1
        )
    )
    
    if "%_GS_VALID%" == "0" (
        echo.
        echo FAIL: Remote "%_GS_REMOTE%" does not exist
        echo.
        exit /B 1
    )
    
    set _GS_VALID=0
    set _GS_BRANCH_SELECTED=0
    set _GS_PREVIOUS_BRANCH=
    echo Checking branches...
    for /F "tokens=1-4 delims= " %%A in ('git branch --list') do (
        if "%%A" == "*" (
            set _GS_PREVIOUS_BRANCH=%%B
            if "!_GS_BRANCH!" == "" (
                echo Using default branch '%%B'
                set _GS_BRANCH=%%B
                set _GS_VALID=1
                set _GS_BRANCH_SELECTED=1
            ) else (
                if "!_GS_BRANCH!" == "%%B" (
                    set _GS_VALID=1
                    set _GS_BRANCH_SELECTED=1
                )
            )
        ) else (
            if not "!_GS_BRANCH!" == "" (
                if "!_GS_BRANCH!" == "%%A" set _GS_VALID=1
            )
        )
    )
    
    if "%_GS_VALID%" == "0" (
        echo.
        if not "%_GS_BRANCH%" == "" (
            echo FAIL: Branch "%_GS_BRANCH%" does not exist
        ) else (
            echo FAIL: Default branch cannot be identified
        )
        echo.
        exit /B 1
    )
    
    echo Fetching "%_GS_REMOTE%" information...
    (git fetch "%_GS_REMOTE%") || (
        echo.
        echo FAIL: 'git fetch "%_GS_REMOTE%"' failed.
        echo.
        exit /B 1
    )
    
    if "%_GS_BRANCH_SELECTED%" == "0" (
        echo Checking out "%_GS_BRANCH%"...
        (git checkout "%_GS_BRANCH%") || (
            echo.
            echo FAIL: 'git fetch "%_GS_BRANCH%"' failed.
            echo.
            exit /B 1
        )
    )
    
    echo Merging "%_GS_REMOTE%" "%_GS_BRANCH%"...
    (git merge "%_GS_REMOTE%/%_GS_BRANCH%") || (
        echo.
        echo FAIL: 'git merge "%_GS_REMOTE%/%_GS_BRANCH%"' failed.
        echo.
        exit /B 1
    )
    
    if not "%_GS_BRANCH%" == "%_GS_PREVIOUS_BRANCH%" (
        echo.
        echo NOTE: Branch '%_GS_BRANCH%' is checked out ^(previously '%_GS_PREVIOUS_BRANCH%' was^)
        echo.
    )
    
    endlocal
    
    echo.
    echo Done
    echo.
