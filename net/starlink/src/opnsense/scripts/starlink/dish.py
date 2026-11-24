#!/usr/local/bin/python3

# Copyright (C) 2026 os-starlink contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

"""
OPNsense Starlink plugin backend.

Called by configd (see actions_starlink.conf). Every command prints a single
JSON object: {"ok": true, ...} or {"ok": false, "error": "..."}.

Usage:
  dish.py status
  dish.py history [seconds]
  dish.py obstruction
  dish.py info
  dish.py sleep show | sleep set HH:MM HH:MM | sleep off
  dish.py wake [hours]          (0 = until resumed)
  dish.py resume
  dish.py resync                (run from cron every few minutes)
  dish.py reboot | stow | unstow
  dish.py gps on|off
  dish.py snowmelt auto|on|off
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from starlink_client import Dish, DishError  # noqa: E402

CONFIG_XML = os.environ.get('STARLINK_CONFIG_XML', '/conf/config.xml')
STATE_FILE = os.environ.get('STARLINK_STATE_FILE', '/var/db/starlink/state.json')
HHMM = re.compile(r'^([01]\d|2[0-3]):([0-5]\d)$')

DEFAULTS = {
    'host': '192.168.100.1', 'port': '9200', 'web_port': '9201', 'transport': 'auto', 'timeout': '10',
    'managed': '0', 'start': '01:00', 'end': '06:00', 'model': 'auto',
}

# Features of the dish API the plugin can use, per hardware model. "auto" picks the model from the
# hardware version the dish reports and falls back to "all" (everything enabled) when it is unknown.
# This table is best effort: if your model is missing a feature, choose "all" in the plugin settings.
FEATURES = ('status', 'history', 'obstruction_map', 'sleep', 'stow', 'snow_melt', 'gps_control', 'pointing')
MODELS = {
    'all': {'name': 'Show everything', 'features': FEATURES},
    'gen1': {'name': 'Standard, round (Gen 1)',
             'features': ('status', 'history', 'obstruction_map', 'sleep', 'stow', 'snow_melt', 'gps_control', 'pointing')},
    'gen2': {'name': 'Standard Actuated (Gen 2)',
             'features': ('status', 'history', 'obstruction_map', 'sleep', 'stow', 'snow_melt', 'gps_control', 'pointing')},
    'gen3': {'name': 'Standard (Gen 3)',
             'features': ('status', 'history', 'obstruction_map', 'sleep', 'snow_melt', 'gps_control', 'pointing')},
    'hp': {'name': 'Performance / High Performance',
           'features': ('status', 'history', 'obstruction_map', 'sleep', 'snow_melt', 'gps_control', 'pointing')},
    'mini': {'name': 'Mini',
             'features': ('status', 'history', 'obstruction_map', 'sleep', 'gps_control', 'pointing')},
}
# hardware_version prefix reported by the dish -> model key (checked in order)
HARDWARE_PREFIXES = (('rev1_', 'gen1'), ('rev2_', 'gen2'), ('rev3_', 'gen3'), ('rev4_', 'gen3'),
                     ('hp', 'hp'), ('mini', 'mini'))
# command -> feature it needs
COMMAND_FEATURE = {
    'history': 'history', 'obstruction': 'obstruction_map',
    'sleep': 'sleep', 'wake': 'sleep', 'resume': 'sleep', 'resync': 'sleep',
    'stow': 'stow', 'unstow': 'stow', 'snowmelt': 'snow_melt', 'gps': 'gps_control',
}


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def load_config():
    cfg = dict(DEFAULTS)
    try:
        root = ET.parse(CONFIG_XML).getroot()
        node = root.find('./OPNsense/starlink')
        if node is not None:
            for section in ('general', 'schedule'):
                sec = node.find(section)
                if sec is None:
                    continue
                for child in sec:
                    if child.text is not None and child.text.strip() != '':
                        cfg[child.tag] = child.text.strip()
    except (OSError, ET.ParseError):
        pass
    cfg['managed'] = cfg.get('managed') == '1'
    return cfg


def make_dish(cfg):
    return Dish(cfg['host'], cfg['port'], cfg['web_port'], cfg['transport'], cfg['timeout'])


def resolve_model(cfg, hardware_version=None, has_actuators=None):
    """Work out the model and the usable features from the setting and what the dish reports."""
    chosen = cfg.get('model', 'auto')
    if chosen != 'auto' and chosen not in MODELS:
        chosen = 'auto'
    detected = None
    hw = (hardware_version or '').lower()
    for prefix, key in HARDWARE_PREFIXES:
        if hw.startswith(prefix):
            detected = key
            break
    key = chosen if chosen != 'auto' else (detected or 'all')
    features = set(MODELS[key]['features'])
    if chosen == 'auto':
        # the dish itself says whether it has motors
        if has_actuators == 'HAS_ACTUATORS_NO':
            features.discard('stow')
        elif has_actuators == 'HAS_ACTUATORS_YES':
            features.add('stow')
    return {'selected': chosen, 'detected': detected, 'key': key, 'name': MODELS[key]['name'],
            'features': sorted(features), 'known_models': {k: v['name'] for k, v in MODELS.items()}}


def load_state():
    try:
        with open(STATE_FILE) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    tmp = STATE_FILE + '.tmp'
    with open(tmp, 'w') as fh:
        json.dump(state, fh)
    os.replace(tmp, STATE_FILE)


def clear_state():
    try:
        os.unlink(STATE_FILE)
    except OSError:
        pass


def parse_hhmm(value):
    m = HHMM.match(value or '')
    if not m:
        raise DishError('invalid time %r, use HH:MM (24-hour)' % value)
    return int(m.group(1)), int(m.group(2))


def local_window_to_utc(start, end):
    """Local HH:MM start/end -> (start minutes past midnight UTC, duration minutes), for today."""
    sh, sm = parse_hhmm(start)
    eh, em = parse_hhmm(end)
    duration = ((eh * 60 + em) - (sh * 60 + sm)) % 1440
    if duration == 0:
        raise DishError('sleep start and end must differ')
    local_start = datetime.now().replace(hour=sh, minute=sm, second=0, microsecond=0)
    utc_start = local_start.astimezone(timezone.utc)
    return utc_start.hour * 60 + utc_start.minute, duration


def utc_minutes_to_local(minutes):
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    return (today + timedelta(minutes=minutes)).astimezone().strftime('%H:%M')


def sleep_info(config):
    enabled = bool(config.get('power_save_mode'))
    start = int(config.get('power_save_start_minutes', 0))
    duration = int(config.get('power_save_duration_minutes', 0))
    info = {'enabled': enabled, 'start_utc_minutes': start, 'duration_minutes': duration}
    if enabled and duration:
        info['start_local'] = utc_minutes_to_local(start)
        info['end_local'] = utc_minutes_to_local((start + duration) % 1440)
    return info


def hold_info():
    state = load_state()
    if not state:
        return None
    until = state.get('wake_until') or 0
    return {
        'until': until,
        'until_local': datetime.fromtimestamp(until).strftime('%Y-%m-%d %H:%M') if until else None,
        'indefinite': not until,
    }


def _r(value, digits=1):
    return None if value is None else round(value, digits)


def update_info(st):
    """Dish firmware update status. The dish downloads updates itself and installs them on reboot."""
    stats = st.get('software_update_stats') or {}
    state = st.get('software_update_state') or stats.get('software_update_state')
    ready = bool(st.get('swupdate_reboot_ready') or stats.get('update_requires_reboot')
                 or state == 'REBOOT_REQUIRED')
    busy = state in ('FETCHING', 'PRE_CHECK', 'WRITING', 'POST_CHECK')
    return {'state': state, 'progress': _r(stats.get('software_update_progress'), 2), 'ready': ready,
            'in_progress': busy and not ready, 'reboot_in_s': st.get('seconds_until_swupdate_reboot_possible'),
            'scheduled_utc': stats.get('reboot_scheduled_utc_time') or None}


# --------------------------------------------------------------------------
# plugin self-update (only contacts GitHub when asked)
# --------------------------------------------------------------------------

PLUGIN_REPO = os.environ.get('STARLINK_PLUGIN_REPO', 'horizon10t/os-starlink')
PLUGIN_BRANCH = os.environ.get('STARLINK_PLUGIN_BRANCH', 'main')
RAW_BASE = 'https://raw.githubusercontent.com/%s/%s/' % (PLUGIN_REPO, PLUGIN_BRANCH)
VERSION_PATH = 'net/starlink/src/opnsense/scripts/starlink/VERSION'
VERSION_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'VERSION')
UPDATE_LOG = '/var/log/starlink-update.log'


def parse_version(text):
    m = re.match(r'^\s*v?(\d+(?:\.\d+)*)', text or '')
    if not m:
        raise DishError('cannot read version %r' % (text or '')[:40])
    return tuple(int(p) for p in m.group(1).split('.'))


def installed_version():
    try:
        with open(VERSION_FILE) as fh:
            return fh.read().strip() or None
    except OSError:
        return None


def latest_version():
    request = urllib.request.Request(RAW_BASE + VERSION_PATH, headers={'User-Agent': 'os-starlink'})
    try:
        with urllib.request.urlopen(request, timeout=10) as resp:
            return resp.read(200).decode('utf-8', 'replace').strip()
    except (OSError, ValueError) as exc:
        raise DishError('cannot check GitHub for updates: %s' % exc)


def pkg_managed():
    """True when installed as a package (then the firmware page does the updating)."""
    try:
        return subprocess.run(['/usr/sbin/pkg', 'info', '-e', 'os-starlink'], timeout=10,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def mbps(bps):
    return round((bps or 0) / 1e6, 2)


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------

def cmd_status(cfg, dish, _args):
    st = dish.get_status()
    alerts = sorted(k for k, v in (st.get('alerts') or {}).items() if v is True)
    outage = st.get('outage') or {}
    if 'is_power_save_idle' in alerts or outage.get('cause') == 'SLEEPING':
        state = 'SLEEPING'
    elif outage:
        state = str(outage.get('cause', 'UNKNOWN'))
    else:
        state = 'CONNECTED'
    dev = st.get('device_info') or {}
    obs = st.get('obstruction_stats') or {}
    gps = st.get('gps_stats') or {}
    align = st.get('alignment_stats') or {}
    config = st.get('config') or {}
    return {
        'state': state,
        'outage': outage or None,
        'alerts': alerts,
        'uptime_s': int((st.get('device_state') or {}).get('uptime_s', 0)),
        'device': {
            'id': dev.get('id'), 'hardware_version': dev.get('hardware_version'),
            'software_version': dev.get('software_version'), 'country_code': dev.get('country_code'),
            'bootcount': dev.get('bootcount'),
        },
        'latency_ms': round(st.get('pop_ping_latency_ms', 0) or 0, 1),
        'drop_rate': round(st.get('pop_ping_drop_rate', 0) or 0, 4),
        'downlink_mbps': mbps(st.get('downlink_throughput_bps')),
        'uplink_mbps': mbps(st.get('uplink_throughput_bps')),
        'eth_speed_mbps': st.get('eth_speed_mbps'),
        'obstruction': {
            'currently_obstructed': bool(obs.get('currently_obstructed')),
            'fraction_obstructed': round(obs.get('fraction_obstructed', 0) or 0, 4),
            'time_obstructed': round(obs.get('time_obstructed', 0) or 0, 4),
            'avg_prolonged_duration_s': _r(obs.get('avg_prolonged_obstruction_duration_s')),
        },
        'gps': {'valid': bool(gps.get('gps_valid')), 'sats': gps.get('gps_sats', 0),
                'inhibited': bool(gps.get('inhibit_gps'))},
        'stow_requested': bool(st.get('stow_requested')),
        'has_actuators': st.get('has_actuators') or align.get('has_actuators'),
        'tilt_angle_deg': _r(align.get('tilt_angle_deg')),
        'azimuth_deg': _r(align.get('boresight_azimuth_deg', st.get('boresight_azimuth_deg'))),
        'elevation_deg': _r(align.get('boresight_elevation_deg', st.get('boresight_elevation_deg'))),
        'software_update_state': st.get('software_update_state'),
        'update': update_info(st),
        'snow_melt_mode': config.get('snow_melt_mode', 'AUTO') if config else None,
        'sleep': sleep_info(config),
        'managed_schedule': {'enabled': cfg['managed'], 'start': cfg['start'], 'end': cfg['end']},
        'wake_hold': hold_info(),
        'transport': dish.used_transport,
        'model': resolve_model(cfg, dev.get('hardware_version'),
                               st.get('has_actuators') or align.get('has_actuators')),
    }


def _ordered(arr, current, count):
    """Return the last `count` samples of a ring buffer in chronological order."""
    size = len(arr)
    if not size:
        return []
    count = min(count, size, current or size)
    end = current % size
    seq = arr[end:] + arr[:end] if current >= size else arr[:end]
    return seq[-count:]


def _downsample(values, points, mode='avg'):
    if len(values) <= points:
        return values
    step = len(values) / points
    out = []
    for i in range(points):
        chunk = values[int(i * step):int((i + 1) * step)] or [values[int(i * step)]]
        out.append(max(chunk) if mode == 'max' else sum(chunk) / len(chunk))
    return out


def _outage_time(start_ns):
    """Outage timestamps appear to be GPS-epoch nanoseconds; fall back to Unix epoch if implausible."""
    now = datetime.now(timezone.utc)
    gps = datetime(1980, 1, 6, tzinfo=timezone.utc) + timedelta(microseconds=start_ns / 1000) \
        - timedelta(seconds=18)  # GPS-UTC leap seconds
    if now - timedelta(days=7) <= gps <= now + timedelta(hours=1):
        return gps
    return datetime.fromtimestamp(start_ns / 1e9, timezone.utc)


def cmd_history(_cfg, dish, args):
    seconds = int(args[0]) if args else 900
    seconds = max(60, min(seconds, 43200))
    h = dish.get_history()
    current = int(h.get('current', 0))
    series = {}
    for key, out, mode, scale in (
            ('pop_ping_latency_ms', 'latency_ms', 'avg', 1),
            ('pop_ping_drop_rate', 'drop_rate', 'max', 1),
            ('downlink_throughput_bps', 'downlink_mbps', 'avg', 1e-6),
            ('uplink_throughput_bps', 'uplink_mbps', 'avg', 1e-6),
            ('power_in', 'power_w', 'avg', 1)):
        vals = _ordered(h.get(key, []), current, seconds)
        series[out] = [round(v * scale, 3) for v in _downsample(vals, 600, mode)]
    samples = len(series['latency_ms'])
    outages = []
    for o in (h.get('outages') or [])[-50:]:
        start = _outage_time(int(o.get('start_timestamp_ns', 0)))
        outages.append({
            'cause': o.get('cause', 'UNKNOWN'),
            'start_local': start.astimezone().strftime('%Y-%m-%d %H:%M:%S'),
            'duration_s': round(int(o.get('duration_ns', 0)) / 1e9, 1),
        })
    return {'seconds': min(seconds, len(_ordered(h.get('pop_ping_latency_ms', []), current, seconds))),
            'points': samples, 'series': series, 'outages': list(reversed(outages))}


def cmd_obstruction(_cfg, dish, _args):
    m = dish.get_obstruction_map()
    return {'rows': m.get('num_rows', 0), 'cols': m.get('num_cols', 0),
            'snr': [round(v, 3) for v in m.get('snr', [])],
            'min_elevation_deg': m.get('min_elevation_deg'), 'max_theta_deg': m.get('max_theta_deg'),
            'frame': m.get('map_reference_frame')}


def cmd_info(_cfg, dish, _args):
    out = {'config': dish.get_config()}
    out['sleep'] = sleep_info(out['config'])
    try:
        loc = dish.get_location()
        lla = loc.get('lla') or {}
        out['location'] = {'lat': lla.get('lat'), 'lon': lla.get('lon'), 'alt': lla.get('alt'),
                           'source': loc.get('source')}
    except DishError as exc:
        out['location'] = {'error': str(exc)}
    return out


def _apply_window(dish, start, end):
    start_utc, duration = local_window_to_utc(start, end)
    dish.set_power_save(True, start_utc, duration)
    return {'start_local': start, 'end_local': end, 'start_utc_minutes': start_utc, 'duration_minutes': duration}


def cmd_sleep(cfg, dish, args):
    sub = args[0] if args else 'show'
    if sub == 'show':
        return {'sleep': sleep_info(dish.get_config()), 'wake_hold': hold_info()}
    if cfg['managed']:
        raise DishError('the sleep schedule is managed by OPNsense; change it under Settings, '
                        'or use Wake for a temporary override')
    if sub == 'set':
        if len(args) != 3:
            raise DishError('usage: sleep set HH:MM HH:MM')
        result = _apply_window(dish, args[1], args[2])
        clear_state()
        return {'message': 'Sleep schedule enabled', 'applied': result}
    if sub == 'off':
        dish.set_power_save(False)
        clear_state()
        return {'message': 'Sleep schedule disabled'}
    raise DishError('unknown sleep command %r' % sub)


def cmd_wake(cfg, dish, args):
    hours = float(args[0]) if args and args[0] != '' else 0
    if hours < 0 or hours > 168:
        raise DishError('wake hours must be between 0 and 168')
    config = dish.get_config()
    existing = load_state()
    prev = existing.get('prev') if existing else None
    if config.get('power_save_mode'):
        prev = {'start': int(config.get('power_save_start_minutes', 0)),
                'duration': int(config.get('power_save_duration_minutes', 1))}
    dish.set_power_save(False)
    until = int(time.time() + hours * 3600) if hours else 0
    if prev or cfg['managed']:
        save_state({'wake_until': until, 'prev': prev, 'created': int(time.time())})
        if until:
            msg = 'Dish awake; sleep schedule resumes at %s' % datetime.fromtimestamp(until).strftime('%H:%M %d %b')
        else:
            msg = 'Dish awake; sleep schedule paused until you resume it'
    else:
        msg = 'Dish awake (no sleep schedule was active)'
    return {'message': msg, 'wake_hold': hold_info()}


def _restore(cfg, dish, state):
    if cfg['managed']:
        applied = _apply_window(dish, cfg['start'], cfg['end'])
    elif state and state.get('prev'):
        prev = state['prev']
        dish.set_power_save(True, int(prev['start']), int(prev['duration']))
        applied = sleep_info({'power_save_mode': True, 'power_save_start_minutes': prev['start'],
                              'power_save_duration_minutes': prev['duration']})
    else:
        applied = None
    clear_state()
    return applied


def cmd_resume(cfg, dish, _args):
    applied = _restore(cfg, dish, load_state())
    if applied is None:
        return {'message': 'Nothing to resume (no saved sleep schedule)'}
    return {'message': 'Sleep schedule resumed', 'applied': applied}


def cmd_resync(cfg, dish, _args):
    state = load_state()
    now = time.time()
    if state:
        until = state.get('wake_until') or 0
        if until and now >= until:
            return {'action': 'restored', 'applied': _restore(cfg, dish, state)}
        return {'action': 'hold', 'wake_hold': hold_info()}
    if not cfg['managed']:
        return {'action': 'none'}
    want_start, want_duration = local_window_to_utc(cfg['start'], cfg['end'])
    current = dish.get_config()
    if (current.get('power_save_mode') and int(current.get('power_save_start_minutes', -1)) == want_start
            and int(current.get('power_save_duration_minutes', -1)) == want_duration):
        return {'action': 'in_sync'}
    dish.set_power_save(True, want_start, want_duration)
    return {'action': 'applied', 'start_utc_minutes': want_start, 'duration_minutes': want_duration}


def cmd_reboot(_cfg, dish, _args):
    dish.reboot()
    return {'message': 'Reboot requested; the dish will be offline for a few minutes'}


def cmd_stow(_cfg, dish, _args):
    dish.stow()
    return {'message': 'Stow requested'}


def cmd_unstow(_cfg, dish, _args):
    dish.stow(unstow=True)
    return {'message': 'Unstow requested'}


def cmd_gps(_cfg, dish, args):
    if not args or args[0] not in ('on', 'off'):
        raise DishError('usage: gps on|off')
    dish.inhibit_gps(args[0] == 'off')
    return {'message': 'GPS %s' % ('enabled' if args[0] == 'on' else 'disabled')}


def cmd_snowmelt(_cfg, dish, args):
    modes = {'auto': 'AUTO', 'on': 'ALWAYS_ON', 'off': 'ALWAYS_OFF'}
    if not args or args[0] not in modes:
        raise DishError('usage: snowmelt auto|on|off')
    dish.set_snow_melt(modes[args[0]])
    return {'message': 'Snow melt set to %s' % modes[args[0]]}


def cmd_plugin_check(_cfg, _dish, _args):
    installed = installed_version()
    latest = latest_version()
    available = bool(installed) and parse_version(latest) > parse_version(installed)
    return {'installed': installed, 'latest': latest, 'available': available,
            'pkg_managed': pkg_managed(), 'repo': PLUGIN_REPO}


def cmd_plugin_update(cfg, dish, args):
    if pkg_managed():
        raise DishError('This plugin was installed as a package. Update it under System > Firmware > Plugins.')
    info = cmd_plugin_check(cfg, dish, args)
    if not info['available']:
        return {'message': 'Already up to date (%s)' % info['installed'], 'started': False}
    script = '/usr/bin/fetch -qo - %sinstall.sh | /bin/sh' % RAW_BASE
    # run detached: the installer restarts configd, which would otherwise kill this process
    subprocess.Popen(['/bin/sh', '-c', '%s > %s 2>&1' % (script, UPDATE_LOG)], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return {'message': 'Updating to %s. Reload this page in about a minute (log: %s).' % (info['latest'], UPDATE_LOG),
            'started': True}


COMMANDS = {
    'plugin_check': cmd_plugin_check, 'plugin_update': cmd_plugin_update,
    'status': cmd_status, 'history': cmd_history, 'obstruction': cmd_obstruction, 'info': cmd_info,
    'sleep': cmd_sleep, 'wake': cmd_wake, 'resume': cmd_resume, 'resync': cmd_resync,
    'reboot': cmd_reboot, 'stow': cmd_stow, 'unstow': cmd_unstow, 'gps': cmd_gps, 'snowmelt': cmd_snowmelt,
}


def main(argv):
    # configd passes parameters as separate argv items; tolerate empty strings
    argv = [a for a in argv if a != '']
    if not argv or argv[0] not in COMMANDS:
        print(json.dumps({'ok': False, 'error': 'usage: dish.py <%s> [args]' % '|'.join(COMMANDS)}))
        return 1
    cfg = load_config()
    try:
        feature = COMMAND_FEATURE.get(argv[0])
        selected = cfg.get('model', 'auto')
        # only enforce when a model was chosen explicitly; in auto mode the dish decides
        if feature and selected in MODELS and feature not in MODELS[selected]['features']:
            raise DishError('%s is not supported on the selected model (%s)' % (argv[0], MODELS[selected]['name']))
        result = COMMANDS[argv[0]](cfg, make_dish(cfg), argv[1:])
        result = dict(result, ok=True)
    except (DishError, ValueError) as exc:
        result = {'ok': False, 'error': str(exc)}
    print(json.dumps(result))
    # Always exit 0: configd discards stdout when a script exits non-zero, and the
    # UI needs the JSON error message. Success or failure is in the "ok" field.
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
