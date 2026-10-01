@echo off
"%FAKE_PWSH%" -NoProfile -File "%~dp0fake-gh.ps1" %*
