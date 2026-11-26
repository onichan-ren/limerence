@echo off
setlocal enabledelayedexpansion

set "POTASSIUM_WORKSPACE=C:\Users\user\AppData\Local\Potassium\workspace"

if not exist "output" mkdir output

set /a success_count=0
set /a total_count=0

echo Scanning for games...
for /d %%G in (..\..\src\game\*) do (
    if exist "%%G\init.luau" (
        set /a total_count+=1
        set "game_name=%%~nxG"
        
        echo.
        echo [!total_count!] Building: !game_name!
        echo ----------------------------------------
        
        darklua process "%%G\init.luau" "output\!game_name!.debug.luau" --config debug.darklua.json

        if !errorlevel! equ 0 (
            set /a success_count+=1

            powershell -NoProfile -Command "(Get-Content -Raw 'output\!game_name!.debug.luau') -replace '--\[=\[[\s\S]*?\]=\]', '' -replace '--\[\[[\s\S]*?\]\]', '' | Set-Content -NoNewline 'output\!game_name!.debug.luau'"

            if exist "%POTASSIUM_WORKSPACE%" (
                copy /y "output\!game_name!.debug.luau" "%POTASSIUM_WORKSPACE%\!game_name!.debug.luau" >nul
            )

            echo SUCCESS: !game_name!.debug.luau
            
            for %%F in ("output\!game_name!.debug.luau") do (
                set size=%%~zF
                set /a size_kb=!size!/1024
                echo    Size: !size_kb! KB
            )
        ) else (
            echo FAILED: !game_name!
        )
    )
)

echo.
echo ==========================================
echo               BUILD SUMMARY
echo ==========================================
echo Total games found: %total_count%
echo Successful builds: %success_count%
set /a failed_count=%total_count%-%success_count%
echo Failed builds: %failed_count%
echo.

if %failed_count% gtr 0 (
    echo Some builds failed. Check output above.
    pause
    exit /b 1
)

echo All builds completed successfully!

if %success_count% gtr 0 (
    echo Built files:
    for %%F in (output\*.luau) do (
        echo    %%~nxF
    )
    echo.
)

timeout /t 2 >nul
