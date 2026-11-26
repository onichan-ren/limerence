@echo off
cd /d "%~dp0"
node refresh-wally.js
node patch-react.js
node patch-cloneref.js