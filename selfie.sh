#!/bin/sh

# Show a small window of the current camera input.
# Requires: apt-get install gstreamer1.0-tools

exec gst-launch-1.0 v4l2src device=/dev/video0 '!' videoscale '!' 'video/x-raw,width=480' '!' autovideosink

