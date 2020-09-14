#!/bin/sh

# Play "masking noise" just loud enough to block out sounds outside the room,
# but not loud enough to drown out normal-volume speech in audio conferences.

exec play -c 2 -n synth brownnoise gain -24 highpass 100 "$@"

