@echo off
    
    rem Synchronizes the changes from upstream repositories (can be overridden)
    rem
    rem Source: https://help.github.com/articles/syncing-a-fork/
    
    setlocal ENABLEDELAYEDEXPANSION
    
    set THIS=%~nx0
    set GS_REMOTE_DEFAULT=upstream
    
    if /i "%~1" == "-h" goto usage
    if /i "%~1" == "-help" goto usage
    if /i "%~1" == "--help" goto usage
    if /i "%~1" == "-?" goto usage
    goto start
    
:usage
    echo.
    echo usage: %THIS% [branch [remote]]
    echo.
    echo        branch - Branch to synchronize to ^(default is currently selected branch^)
    echo        remote - Remote to synchronize from ^(default is "%GS_REMOTE_DEFAULT%"^)
    echo.
    exit /B 1
    
:start
    set GS_BRANCH=%~1
    rem NOTE: if branch is not specified, then we accept the currently selected branch
    set GS_REMOTE=%~2
    if "%GS_REMOTE%" == "" set GS_REMOTE=%GS_REMOTE_DEFAULT%
    
    if not exist ".git" (
        echo.
        echo FAIL: Current folder does not belong to a git repository
        echo.
        exit /B 1
    )
    
    echo.
    echo Syncing checking with '%GS_REMOTE%' repository
    echo.
    
    set GS_VALID=0
    echo Checking remotes...
    for /F "tokens=1-4 delims= " %%A in ('git remote show') do (
        if "%%A" == "!GS_REMOTE!" (
            set GS_VALID=1
        )
    )
    
    if "%GS_VALID%" == "0" (
        echo.
        echo FAIL: Remote "%GS_REMOTE%" does not exist
        echo.
        exit /B 1
    )
    
    set GS_VALID=0
    set GS_BRANCH_SELECTED=0
    set GS_PREVIOUS_BRANCH=
    echo Checking branches...
    for /F "tokens=1-4 delims= " %%A in ('git branch --list') do (
        if "%%A" == "*" (
            set GS_PREVIOUS_BRANCH=%%B
            if "!GS_BRANCH!" == "" (
                echo Using default branch '%%B'
                set GS_BRANCH=%%B
                set GS_VALID=1
                set GS_BRANCH_SELECTED=1
            ) else (
                if "!GS_BRANCH!" == "%%B" (
                    set GS_VALID=1
                    set GS_BRANCH_SELECTED=1
                )
            )
        ) else (
            if not "!GS_BRANCH!" == "" (
                if "!GS_BRANCH!" == "%%A" set GS_VALID=1
            )
        )
    )
    
    if "%GS_VALID%" == "0" (
        echo.
        if not "%GS_BRANCH%" == "" (
            echo FAIL: Branch "%GS_BRANCH%" does not exist
        ) else (
            echo FAIL: Default branch cannot be identified
        )
        echo.
        exit /B 1
    )
    
    echo Fetching "%GS_REMOTE%" information...
    (git fetch "%GS_REMOTE%") || (
        echo.
        echo FAIL: 'git fetch "%GS_REMOTE%"' failed.
        echo.
        exit /B 1
    )
    
    if "%GS_BRANCH_SELECTED%" == "0" (
        echo Checking out "%GS_BRANCH%"...
        (git checkout "%GS_BRANCH%") || (
            echo.
            echo FAIL: 'git fetch "%GS_BRANCH%"' failed.
            echo.
            exit /B 1
        )
    )
    
    echo Merging "%GS_REMOTE%" "%GS_BRANCH%"...
    (git merge "%GS_REMOTE%/%GS_BRANCH%") || (
        echo.
        echo FAIL: 'git merge "%GS_REMOTE%/%GS_BRANCH%"' failed.
        echo.
        exit /B 1
    )
    
    if not "%GS_BRANCH%" == "%GS_PREVIOUS_BRANCH%" (
        echo.
        echo NOTE: Branch '%GS_BRANCH%' is checked out ^(previously '%GS_PREVIOUS_BRANCH%' was^)
        echo.
    )
    
    endlocal
    
    echo.
    echo Done
    echo.
