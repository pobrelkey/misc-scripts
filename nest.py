#!/usr/bin/env python3


# Start an alternate VNC-based desktop session on your local machine 
# to which you and others can connect; or, start a "nested" desktop 
# which runs in a window on your primary desktop.
#
# Why is this useful?
# * If your team's chat software (Teams, Slack) only offers the option
#   to share your entire desktop, but your desktop is huge (2x4K monitors
#   in my case) - gives you a smaller desktop where sharing it to others
#   isn't considered a DoS attack.
# * If you're on a smaller monitor, do desktop sharing frequently, but 
#   would prefer everything you do weren't in view of the remote user(s) -
#   gives you a "sandbox" which can be shared while your main desktop 
#   remains out of view.
#
# Example invocation:
#
#     nest.sh --type=vnc --gemoetry=1920x1080 &
#
# Run `nest.sh --help` for slightly more documentation.
#
# Some apps (web browsers in particular) won't play nicely with multiple 
# desktop sessions running on your machine at once - for example, you'll 
# open documents/links in one desktop session and they'll pop up in a 
# different session.  I work around this for web browsers by using separate
# ephemeral profiles for each alternate desktop (for which see freshfox.sh,
# in this repository).
#
# Uses JWM as a window manager by default - it's simple, behaves in a
# civilized manner, and you can run multiple instances at once without harm.
#
# Clipboard sync for XNest/Xephyr based desktops relies on xclipsync,
# which is a git submodule of this repository - make sure you have this
# checked out and have tk installed (apt-get install tk), which it needs.
#
# Has several more dependencies (search the source for "apt-get" 
# to list them all) - you won't need to install all of them.


import argparse, atexit, os, re, shlex, socket, subprocess, sys, time
import psutil # apt-get install python3-psutil

VNC_PORTS_BASE=5900

DEFAULT_SIZE=(1680,1050)
DEFAULT_WM='jwm'  # apt-get install jwm
DEFAULT_DPI=96
DEFAULT_CMDS=['x-terminal-emulator']
DEFAULT_CMD=', '.join(DEFAULT_CMDS)
DEFAULT_SERVER='xephyr'

XCLIPSYNC_PATH=os.path.join(os.path.dirname(__file__), 'xclipsync', 'xclipsync')

def server_xtightvnc(size, dpi, title, display, cmds):
    # apt-get install tightvncserver
    print('>>>> starting %dx%d TightVnc server on port %d' % (*size, VNC_PORTS_BASE+display))
    return ('Xtightvnc', 
        '-s', '10000', 
        '-dpi', str(dpi), 
        '-geometry', '%dx%d' % size, 
        '-desktop', title, 
        ':%d' % display)
def server_xtigervnc(size, dpi, title, display, cmds):
    # apt-get install tigervnc-standalone-server
    print('>>>> starting %dx%d TigerVnc server on port %d' % (*size, VNC_PORTS_BASE+display))
    return ('Xtigervnc', 
        '-s', '10000', 
        '-dpi', str(dpi), 
        '-geometry', '%dx%d' % size, 
        '-desktop', title, 
        '-ZlibLevel', '3', 
        '-PasswordFile', '%s/.vnc/passwd' % os.environ.get('HOME'), 
        ':%d' % display)
def server_xephyr(size, dpi, title, display, cmds):
    # apt-get install xserver-xephyr
    print('>>>> starting %dx%d Xephyr server on :%d' % (*size, display))
    cmds += [XCLIPSYNC_PATH]
    return ('Xephyr', 
        '-retro', '-no-host-grab', 
        '-s', '10000', 
        '-dpi', str(dpi), 
        '-screen', '%dx%d' % size, 
        '-title', title, 
        ':%d' % display)
def server_xnest(size, dpi, title, display, cmds):
    # apt-get install xnest
    print('>>>> starting %dx%d Xnest server on :%d' % (*size, display))
    cmds += [XCLIPSYNC_PATH]
    return ('Xnest', 
        '-retro', '-sss', 
        '-s', '10000', 
        '-dpi', str(dpi), 
        '-geometry', '%dx%d' % size, 
        '-name', title, 
        ':%d' % display)
SERVERS = {
    'vnc':      server_xtigervnc,
    'tightvnc': server_xtightvnc,
    'tigervnc': server_xtigervnc,
    'xephyr':   server_xephyr,
    'xnest':    server_xnest
}
def validate_xserver(s):
    if s not in SERVERS:
        raise argparse.ArgumentTypeError
    return s

SIZE_RX=re.compile(r'''(\d+)x(\d+)''')
def parse_size(size_str):
    m = SIZE_RX.match(size_str)
    if not m:
        raise argparse.ArgumentTypeError
    return (int(m.group(1)),int(m.group(2)))


parser = argparse.ArgumentParser(description='Start a nested desktop')
parser.add_argument('-s', '--size', '--geometry', type=parse_size, dest='size', metavar='WIDTHxHEIGHT', default=DEFAULT_SIZE,
    help=('Desktop size in pixels (default: %dx%d)' % DEFAULT_SIZE))
parser.add_argument('-c', '--command', '--cmd', type=str, nargs='*', dest='commands', metavar='CMDLINE',
    help='Command(s) to run in new desktop (default: %s)' % DEFAULT_CMD)
parser.add_argument('-x', '--xserver', '--server', '--type', type=validate_xserver, dest='xserver', metavar='TYPE', default=DEFAULT_SERVER,
    help='X11 server to use (default: %s)' % DEFAULT_SERVER)
parser.add_argument('-w', '--window-manager', '--wm', type=str, dest='wm', metavar='WMGR', default=DEFAULT_WM,
    help='Window manager to use on new desktop (default: %s)' % DEFAULT_WM)
parser.add_argument('-d', '--dpi', type=int, dest='dpi', metavar='DPI', default=DEFAULT_DPI,
    help='Resolution in dots per inch (default: %s)' % DEFAULT_DPI)
parser.add_argument('-t', '--title', type=str, dest='title', metavar='TITLE', default=None,
    help='Title of nested desktop')
args = parser.parse_args()


commands = list(args.commands if (args.commands is not None and len(args.commands) > 0) else DEFAULT_CMDS)

XN_RX = re.compile(r'^X(\d+)$')
display = min(set(range(0,100)) - set([int(XN_RX.match(x).group(1)) for x in os.listdir('/tmp/.X11-unix/') if XN_RX.match(x)]))
title = args.title or ('nested desktop %d: %s@%s' % (display, os.environ.get('USER'), os.uname().nodename))
xserver_args = SERVERS[args.xserver](args.size, args.dpi, title, display, commands)

with subprocess.Popen(xserver_args, 
        pass_fds=(sys.stdout.fileno(),sys.stderr.fileno())) as xserver:
    children = [xserver]
    def killall():
        for child in children:
            try:
                child.kill()
            except:
                pass
    atexit.register(killall)

    X11_SOCK_RX = re.compile(r'^@?/tmp/\.X11-unix/X(\d+)$')
    displays = []
    polls = 0
    while polls < 20 and len(displays) == 0:
        time.sleep(0.25)
        displays = [int(X11_SOCK_RX.match(x.laddr).group(1)) for x in psutil.Process(xserver.pid).connections('unix') if X11_SOCK_RX.match(x.laddr)]
        polls += 1
    if len(displays) == 0:
        sys.stderr.print('unable to determine display number')
        killall()
        sys.exit(1)
    display = min(displays)

    extra_procs = [args.wm] + commands
    extra_env = dict(os.environ)
    extra_env['DISPLAY'] = ':%d' % display
    for extra in extra_procs:
        extra_args_list = shlex.split(extra)
        children.append(subprocess.Popen(extra_args_list,
                env=extra_env,
                pass_fds=(sys.stdout.fileno(),sys.stderr.fileno())))

    xserver.wait()
