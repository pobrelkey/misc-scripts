#!/usr/bin/env bash

# Run the most-recent version of IntelliJ, stored under ~/opt/idea. 

exec $(ls ~/opt/idea/idea-*/bin/idea.sh | sort -rn | head -1) "$@"

