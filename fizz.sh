#!/bin/sh

# Play "masking noise" just loud enough to block out sounds outside the room,
# but not loud enough to drown out normal-volume speech in audio conferences.
#
# Extra options are passed to the underlying sox binary, so you can adjust
# volume up or down (e.g. "fizz.sh gain -6" to turn it down by 6 db).
#
# Requires sox (apt-get install sox).

exec play -c 2 -n synth brownnoise gain -24 highpass 100 "$@"

