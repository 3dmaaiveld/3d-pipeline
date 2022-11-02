@echo off
@REM run it like: batch hostname port user password dbname area
@REM .\test_batch.bat localhost 5432 postgres *password* paasheuvel_bgt paasheuvel
ogr2ogr -f PostgreSQL "PG:host=%1 port=%2 user=%3 password=%4 dbname=%5" "data\input_bgt\%6.gpkg"
