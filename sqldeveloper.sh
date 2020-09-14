#!/usr/bin/env bash

# Run the most-recent version of SQL Developer, stored under ~/opt/sqldeveloper. 

exec $(ls ~/opt/sqldeveloper/sqldeveloper-*/sqldeveloper.sh | sort -rn | head -1) "$@"

