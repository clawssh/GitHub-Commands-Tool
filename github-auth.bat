@echo off
setlocal enabledelayedexpansion

:: Change to script directory
cd /d "%~dp0"

:: Check and setup tools
where gh >nul 2>&1 || (
    echo Installing GitHub CLI...
    winget install -e --id GitHub.cli
    echo Please restart the tool after installation
    pause
    exit /b
)

:: Auto login if needed
gh auth status >nul 2>&1 || (
    echo Logging in to GitHub...
    gh auth login --web
)

:: Get GitHub username after ensuring gh is installed and authenticated
for /f "usebackq tokens=*" %%a in (`gh api user --jq ".login"`) do set "GITHUB_USER=%%a"

:main_menu
cls
echo.
echo    +================================+
echo    ^|      SIMPLE GITHUB TOOL        ^|
echo    +================================+
echo    ^|         By Clawssh            ^|
echo    +================================+
echo.
echo    Welcome, !GITHUB_USER!
echo    Current folder: %CD%
echo.
echo    +--------------------------------+
echo    ^|  1. Setup New Project          ^|
echo    ^|  2. Clone Existing Project     ^|
echo    ^|  3. Save Changes              ^|
echo    ^|  4. Get Updates               ^|
echo    ^|  5. Exit                      ^|
echo    +--------------------------------+
echo.
set /p choice="    Choose (1-5): "

if "!choice!"=="1" (
    :: Setup new project
    echo Setting up new project...
    for %%I in (.) do set "repo=%%~nxI"
    set /p repo="Repository name [!repo!]: " || set "repo=!repo!"
    
    echo Creating repository on GitHub...
    gh repo create "!repo!" --private --clone
    if !errorlevel! equ 0 (
        echo Repository created successfully
    ) else (
        echo Failed to create repository. Try a different name.
    )
    timeout /t 2 >nul
    goto main_menu
)

if "!choice!"=="2" (
    :: Clone existing project
    set /p repo="Repository URL or name: "
    echo Cloning !repo!...
    
    :: Create temp directory for clone
    set "temp_dir=%TEMP%\gh_tool_temp"
    rmdir /s /q "!temp_dir!" >nul 2>&1
    mkdir "!temp_dir!" >nul 2>&1
    
    :: Try to clone into temp directory first
    pushd "!temp_dir!"
    gh repo clone "!repo!" . && (
        :: Clone successful, move back and copy files
        popd
        echo Moving files...
        
        :: Clean current directory except for our script
        for /f "tokens=*" %%a in ('dir /a /b') do (
            if /i not "%%a"=="github-auth.bat" (
                if exist "%%a\*" (
                    rmdir /s /q "%%a" >nul 2>&1
                ) else (
                    del /f /q "%%a" >nul 2>&1
                )
            )
        )
        
        :: Copy files from temp to current directory
        robocopy "!temp_dir!" "." /E /NFL /NDL /NJH /NJS /nc /ns /np
        rmdir /s /q "!temp_dir!" >nul 2>&1
        echo Clone successful
    ) || (
        :: Clone failed
        popd
        rmdir /s /q "!temp_dir!" >nul 2>&1
        echo Failed to clone repository. Please check:
        echo 1. The repository exists
        echo 2. You have access to it
        echo 3. Try one of these formats:
        echo - Full URL: https://github.com/username/repo
        echo - Short format: username/repo
        echo - Just repo name ^(if it's your repo^)
    )
    timeout /t 2 >nul
    goto main_menu
)

if "!choice!"=="3" (
    :: Save all changes using gh cli
    echo Saving changes...
    gh repo sync --source=. --force || (
        :: If sync fails, try traditional git commands
        git add -A :/
        git reset -- github-auth.bat >nul 2>&1
        set /p msg="Describe your changes (optional): " || set "msg=Update"
        git commit -m "!msg!"
        git push --force-with-lease
    )
    echo Changes saved
    timeout /t 2 >nul
    goto main_menu
)

if "!choice!"=="4" (
    :: Get latest updates using gh cli
    echo Syncing with GitHub...
    
    :: Force reset to match remote state
    git fetch origin
    git reset --hard origin/main || git reset --hard origin/master
    
    echo Update complete
    timeout /t 2 >nul
    goto main_menu
)

if "!choice!"=="5" exit /b

goto main_menu 