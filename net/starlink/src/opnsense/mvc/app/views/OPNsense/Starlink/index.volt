{#
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
 #}

<style>
    :root { --sl-ok: #3c9a3c; --sl-info: #4a7fc1; --sl-warn: #e0a030; --sl-bad: #c9302c; --sl-line: rgba(128,128,128,.28); }
    .sl-section { padding: 14px 18px 18px; }

    /* header strip */
    .sl-head { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 16px; margin-bottom: 16px; }
    .sl-pill { display: inline-flex; align-items: center; gap: 8px; padding: 5px 14px; border-radius: 999px;
               border: 1px solid var(--sl-line); font-weight: 600; letter-spacing: .02em; }
    .sl-dot { width: 10px; height: 10px; border-radius: 50%; background: var(--sl-line); }
    .sl-pill.sl-ok .sl-dot { background: var(--sl-ok); box-shadow: 0 0 0 3px rgba(60,154,60,.2); }
    .sl-pill.sl-info .sl-dot { background: var(--sl-info); box-shadow: 0 0 0 3px rgba(74,127,193,.2); }
    .sl-pill.sl-bad .sl-dot { background: var(--sl-bad); box-shadow: 0 0 0 3px rgba(201,48,44,.2); }
    .sl-meta { opacity: .75; font-size: 13px; }
    .sl-head .sl-spacer { flex: 1 1 auto; }
    .sl-updated { font-size: 12px; opacity: .6; }

    /* KPI tiles */
    .sl-tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 12px; margin-bottom: 18px; }
    .sl-tile { position: relative; border: 1px solid var(--sl-line); border-radius: 6px; padding: 12px 14px 10px 17px; overflow: hidden; }
    .sl-tile:before { content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 4px; background: var(--sl-line); }
    .sl-tile.sl-ok:before { background: var(--sl-ok); }
    .sl-tile.sl-info:before { background: var(--sl-info); }
    .sl-tile.sl-warn:before { background: var(--sl-warn); }
    .sl-tile.sl-bad:before { background: var(--sl-bad); }
    .sl-tile .sl-label { font-size: 11px; text-transform: uppercase; letter-spacing: .06em; opacity: .65; }
    .sl-tile .sl-label i { margin-right: 4px; }
    .sl-tile .sl-value { font-size: 26px; font-weight: 600; line-height: 1.25; }
    .sl-tile .sl-unit { font-size: 13px; font-weight: 400; opacity: .7; margin-left: 3px; }
    .sl-tile .sl-sub { font-size: 12px; opacity: .7; min-height: 16px; }

    /* cards */
    .sl-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; align-items: start; }
    .sl-card { border: 1px solid var(--sl-line); border-radius: 6px; margin-bottom: 16px; }
    .sl-card-title { padding: 9px 14px; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .06em;
                     border-bottom: 1px solid var(--sl-line); opacity: .85; }
    .sl-card-title i { margin-right: 6px; }
    .sl-card-body { padding: 12px 14px; }
    .sl-kv { display: grid; grid-template-columns: minmax(110px, 38%) 1fr; gap: 6px 12px; margin: 0; }
    .sl-kv dt { font-weight: 400; opacity: .65; }
    .sl-kv dd { margin: 0; word-break: break-word; }
    .sl-row { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-top: 12px; }
    .sl-row .form-control { width: auto; }
    .sl-row select.form-control, .sl-toolbar select.form-control { min-width: 150px; padding-right: 30px; }
    .sl-actions .btn { margin: 0 6px 6px 0; }
    .sl-chip { display: inline-block; margin: 2px 4px 2px 0; padding: 2px 10px; border-radius: 999px; font-size: 12px;
               border: 1px solid var(--sl-line); }
    .sl-chip.sl-info { border-color: var(--sl-info); color: var(--sl-info); }
    .sl-chip.sl-warn { border-color: var(--sl-warn); color: var(--sl-warn); }
    .sl-chip.sl-bad { border-color: var(--sl-bad); color: var(--sl-bad); }
    .sl-msg { margin: 0 0 14px; }
    .sl-empty { opacity: .6; }
    .btn.sl-busy { opacity: .6; pointer-events: none; }

    /* history */
    .sl-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; margin-bottom: 14px; }
    .sl-chart-wrap { position: relative; margin-bottom: 4px; }
    .sl-chart-title { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 4px 12px; font-weight: 600; margin: 14px 0 4px; }
    .sl-chart-title small { font-weight: 400; opacity: .7; }
    .sl-chart { width: 100%; height: 170px; display: block; }
    .sl-tip { position: absolute; pointer-events: none; display: none; z-index: 5; padding: 3px 8px; font-size: 12px;
              border-radius: 4px; background: rgba(20,20,20,.9); color: #fff; white-space: nowrap; }
    .sl-legend { display: inline-flex; align-items: center; gap: 12px; }
    .sl-swatch { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 4px; }

    /* obstruction */
    #sl-obsmap { width: 100%; max-width: 480px; image-rendering: pixelated; border: 1px solid var(--sl-line); border-radius: 50%; background: rgba(128,128,128,.08); }
    .sl-scale { height: 10px; max-width: 480px; border-radius: 5px; margin: 10px 0 2px; background: linear-gradient(90deg, rgb(255,0,40), rgb(128,100,40), rgb(0,200,40)); }
    .sl-scale-labels { display: flex; justify-content: space-between; max-width: 480px; font-size: 11px; opacity: .65; }

    @media (max-width: 767px) { .sl-section { padding: 10px; } .sl-tile .sl-value { font-size: 22px; } }
</style>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab-status"><i class="fa fa-tachometer fa-fw"></i> {{ lang._('Status') }}</a></li>
    <li data-feature="history"><a data-toggle="tab" href="#tab-history"><i class="fa fa-line-chart fa-fw"></i> {{ lang._('History') }}</a></li>
    <li data-feature="obstruction_map"><a data-toggle="tab" href="#tab-obstruction"><i class="fa fa-eye-slash fa-fw"></i> {{ lang._('Obstructions') }}</a></li>
    <li><a data-toggle="tab" href="#tab-settings"><i class="fa fa-cog fa-fw"></i> {{ lang._('Settings') }}</a></li>
</ul>

<div class="tab-content content-box">
    <!-- STATUS -->
    <div id="tab-status" class="tab-pane fade in active sl-section">
        <div id="sl-error" class="alert alert-danger sl-msg" style="display:none"></div>
        <div id="sl-message" class="alert alert-info sl-msg" style="display:none"></div>

        <div class="sl-head">
            <span class="sl-pill" id="sl-pill"><span class="sl-dot"></span><span id="sl-state">&hellip;</span></span>
            <span class="sl-meta" id="sl-headmeta"></span>
            <span class="sl-spacer"></span>
            <span class="sl-updated" id="sl-updated"></span>
            <button class="btn btn-default btn-xs" id="sl-btn-refresh" title="{{ lang._('Refresh now') }}"><i class="fa fa-refresh fa-fw"></i></button>
        </div>

        <div class="sl-tiles">
            <div class="sl-tile" id="sl-t-latency"><div class="sl-label"><i class="fa fa-clock-o"></i>{{ lang._('Latency') }}</div><div class="sl-value" id="sl-latency">&ndash;</div><div class="sl-sub" id="sl-drop"></div></div>
            <div class="sl-tile" id="sl-t-down"><div class="sl-label"><i class="fa fa-arrow-down"></i>{{ lang._('Download') }}</div><div class="sl-value" id="sl-down">&ndash;</div><div class="sl-sub">{{ lang._('current') }}</div></div>
            <div class="sl-tile" id="sl-t-up"><div class="sl-label"><i class="fa fa-arrow-up"></i>{{ lang._('Upload') }}</div><div class="sl-value" id="sl-up">&ndash;</div><div class="sl-sub">{{ lang._('current') }}</div></div>
            <div class="sl-tile" id="sl-t-obs"><div class="sl-label"><i class="fa fa-eye-slash"></i>{{ lang._('Obstructed') }}</div><div class="sl-value" id="sl-obs">&ndash;</div><div class="sl-sub" id="sl-obs-sub"></div></div>
        </div>

        <div class="sl-grid">
            <div>
                <div class="sl-card" data-feature="sleep">
                    <div class="sl-card-title"><i class="fa fa-moon-o"></i>{{ lang._('Sleep schedule') }}</div>
                    <div class="sl-card-body">
                        <dl class="sl-kv">
                            <dt>{{ lang._('Dish schedule') }}</dt><dd id="sl-sleep-current">&ndash;</dd>
                            <dt>{{ lang._('Managed by OPNsense') }}</dt><dd id="sl-sleep-managed">&ndash;</dd>
                            <dt>{{ lang._('Wake override') }}</dt><dd id="sl-sleep-hold">&ndash;</dd>
                        </dl>
                        <div class="sl-row sl-actions">
                            <select id="sl-wake-hours" class="form-control">
                                <option value="1">{{ lang._('for 1 hour') }}</option>
                                <option value="2" selected>{{ lang._('for 2 hours') }}</option>
                                <option value="4">{{ lang._('for 4 hours') }}</option>
                                <option value="8">{{ lang._('for 8 hours') }}</option>
                                <option value="24">{{ lang._('for 24 hours') }}</option>
                                <option value="0">{{ lang._('until I resume') }}</option>
                            </select>
                            <button class="btn btn-primary" id="sl-btn-wake"><i class="fa fa-sun-o fa-fw"></i> {{ lang._('Wake now') }}</button>
                            <button class="btn btn-default" id="sl-btn-resume"><i class="fa fa-moon-o fa-fw"></i> {{ lang._('Resume schedule') }}</button>
                        </div>
                        <div class="sl-row" id="sl-direct-sleep">
                            <input type="time" class="form-control" id="sl-sleep-start" value="01:00">
                            <span>{{ lang._('to') }}</span>
                            <input type="time" class="form-control" id="sl-sleep-end" value="06:00">
                            <button class="btn btn-default" id="sl-btn-sleep-set">{{ lang._('Apply to dish') }}</button>
                            <button class="btn btn-default" id="sl-btn-sleep-off">{{ lang._('Disable sleep') }}</button>
                        </div>
                        <p class="text-muted" id="sl-managed-note" style="display:none; margin:10px 0 0">
                            {{ lang._('The schedule is managed by OPNsense. Change it on the Settings tab.') }}
                        </p>
                    </div>
                </div>

                <div class="sl-card">
                    <div class="sl-card-title"><i class="fa fa-sliders"></i>{{ lang._('Controls') }}</div>
                    <div class="sl-card-body">
                        <div class="sl-actions">
                            <button class="btn btn-warning" id="sl-btn-reboot"><i class="fa fa-refresh fa-fw"></i> {{ lang._('Reboot dish') }}</button>
                            <button class="btn btn-default" data-feature="stow" id="sl-btn-stow">{{ lang._('Stow') }}</button>
                            <button class="btn btn-default" data-feature="stow" id="sl-btn-unstow">{{ lang._('Unstow') }}</button>
                            <button class="btn btn-default" data-feature="gps_control" id="sl-btn-gps">{{ lang._('Toggle GPS') }}</button>
                        </div>
                        <div class="sl-row" data-feature="snow_melt">
                            <label for="sl-snowmelt" style="margin:0">{{ lang._('Snow melt') }}</label>
                            <select id="sl-snowmelt" class="form-control">
                                <option value="auto">{{ lang._('Automatic') }}</option>
                                <option value="on">{{ lang._('Always on') }}</option>
                                <option value="off">{{ lang._('Always off') }}</option>
                            </select>
                            <button class="btn btn-default" id="sl-btn-snowmelt">{{ lang._('Apply') }}</button>
                        </div>
                    </div>
                </div>
            </div>

            <div>
                <div class="sl-card">
                    <div class="sl-card-title"><i class="fa fa-download"></i>{{ lang._('Updates') }}
                        <span class="sl-chip sl-warn" id="sl-upd-badge" style="display:none; margin-left:8px">{{ lang._('Update available') }}</span></div>
                    <div class="sl-card-body">
                        <dl class="sl-kv">
                            <dt>{{ lang._('Dish firmware') }}</dt><dd id="sl-fw-state">&ndash;</dd>
                            <dt>{{ lang._('This plugin') }}</dt><dd id="sl-pl-state">&ndash;</dd>
                        </dl>
                        <div class="sl-row sl-actions">
                            <button class="btn btn-default" id="sl-btn-check"><i class="fa fa-search fa-fw"></i> {{ lang._('Check for updates') }}</button>
                            <button class="btn btn-warning" id="sl-btn-fw-update" style="display:none"><i class="fa fa-download fa-fw"></i> {{ lang._('Update dish now') }}</button>
                            <button class="btn btn-primary" id="sl-btn-pl-update" style="display:none"><i class="fa fa-download fa-fw"></i> {{ lang._('Update plugin') }}</button>
                        </div>
                        <p class="text-muted" style="margin:10px 0 0; font-size:12px">
                            {{ lang._('The dish downloads firmware by itself and installs it on reboot, so "Update dish now" reboots the dish. Checking the plugin contacts GitHub.') }}
                        </p>
                    </div>
                </div>
                <div class="sl-card">
                    <div class="sl-card-title"><i class="fa fa-exclamation-triangle"></i>{{ lang._('Active alerts') }}</div>
                    <div class="sl-card-body" id="sl-alerts"><span class="sl-empty">&ndash;</span></div>
                </div>
                <div class="sl-card">
                    <div class="sl-card-title"><i class="fa fa-info-circle"></i>{{ lang._('Dish') }}</div>
                    <div class="sl-card-body"><dl class="sl-kv" id="sl-details"></dl></div>
                </div>
            </div>
        </div>
    </div>

    <!-- HISTORY -->
    <div id="tab-history" class="tab-pane fade sl-section">
        <div class="sl-toolbar">
            <select id="sl-hist-range" class="form-control" style="width:auto">
                <option value="900">{{ lang._('Last 15 minutes') }}</option>
                <option value="3600" selected>{{ lang._('Last hour') }}</option>
                <option value="21600">{{ lang._('Last 6 hours') }}</option>
                <option value="43200">{{ lang._('Last 12 hours') }}</option>
            </select>
            <button class="btn btn-default" id="sl-btn-hist"><i class="fa fa-refresh fa-fw"></i> {{ lang._('Refresh') }}</button>
            <span class="text-muted" id="sl-hist-note"></span>
        </div>
        <div class="sl-chart-title"><span>{{ lang._('Latency (ms)') }}</span><small id="sl-s-latency"></small></div>
        <div class="sl-chart-wrap"><canvas class="sl-chart" id="sl-c-latency"></canvas><div class="sl-tip"></div></div>
        <div class="sl-chart-title"><span>{{ lang._('Packet loss (%)') }}</span><small id="sl-s-drop"></small></div>
        <div class="sl-chart-wrap"><canvas class="sl-chart" id="sl-c-drop"></canvas><div class="sl-tip"></div></div>
        <div class="sl-chart-title"><span>{{ lang._('Throughput (Mbps)') }}</span>
            <small class="sl-legend"><span><span class="sl-swatch" style="background:#2f7ed8"></span>{{ lang._('down') }}</span><span><span class="sl-swatch" style="background:#e4a32e"></span>{{ lang._('up') }}</span></small></div>
        <div class="sl-chart-wrap"><canvas class="sl-chart" id="sl-c-tput"></canvas><div class="sl-tip"></div></div>
        <div class="sl-chart-title"><span>{{ lang._('Power draw (W)') }}</span><small id="sl-s-power"></small></div>
        <div class="sl-chart-wrap"><canvas class="sl-chart" id="sl-c-power"></canvas><div class="sl-tip"></div></div>
        <h3>{{ lang._('Recent outages') }}</h3>
        <table class="table table-condensed table-striped">
            <thead><tr><th>{{ lang._('Start') }}</th><th>{{ lang._('Cause') }}</th><th>{{ lang._('Duration') }}</th></tr></thead>
            <tbody id="sl-outages"><tr><td colspan="3" class="text-muted">&ndash;</td></tr></tbody>
        </table>
    </div>

    <!-- OBSTRUCTION -->
    <div id="tab-obstruction" class="tab-pane fade sl-section">
        <div class="sl-toolbar">
            <button class="btn btn-default" id="sl-btn-obs"><i class="fa fa-refresh fa-fw"></i> {{ lang._('Refresh') }}</button>
        </div>
        <div class="sl-grid">
            <div>
                <canvas id="sl-obsmap" width="123" height="123"></canvas>
                <div class="sl-scale"></div>
                <div class="sl-scale-labels"><span>{{ lang._('obstructed') }}</span><span>{{ lang._('clear sky') }}</span></div>
            </div>
            <div>
                <p>{{ lang._('Sky view as seen by the dish: the centre is straight up and the edge is the lowest elevation the dish uses. Green = clear sky observed, red = obstructed, blank = not yet observed. The map builds up over about 12 hours.') }}</p>
                <div class="sl-card"><div class="sl-card-body"><dl class="sl-kv" id="sl-obs-details"></dl></div></div>
            </div>
        </div>
    </div>

    <!-- SETTINGS -->
    <div id="tab-settings" class="tab-pane fade">
        {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general']) }}
        {{ partial("layout_partials/base_form", ['fields': scheduleForm, 'id': 'frm_schedule']) }}
        <div class="col-md-12" style="padding:10px 15px 20px">
            <button class="btn btn-primary" id="sl-btn-save"><b>{{ lang._('Save') }}</b> <i id="sl-save-progress" class=""></i></button>
        </div>
    </div>
</div>

<script>
$(function () {
    const T = {
        confirm: "{{ lang._('Are you sure?') }}",
        reboot: "{{ lang._('Reboot the dish? Internet over Starlink will drop for a few minutes.') }}",
        stow: "{{ lang._('Stow the dish? It stops providing internet until unstowed.') }}",
        sleepOff: "{{ lang._('Disable the dish sleep schedule completely?') }}",
        noSchedule: "{{ lang._('Disabled') }}",
        yes: "{{ lang._('Yes') }}", no: "{{ lang._('No') }}",
        none: "{{ lang._('None') }}",
        fwUpdate: "{{ lang._('Reboot the dish now to install the downloaded firmware update? Internet over Starlink will drop for a few minutes.') }}",
        plUpdate: "{{ lang._('Download and install the new plugin version from GitHub? This runs the repository installer as root. The plugin restarts, so reload this page afterwards.') }}",
    };
    const DASH = '–';
    let lastStatus = null;
    let refreshTimer = null;

    function esc(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }
    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + 'd ' : '') + h + 'h ' + m + 'm';
    }
    function fmtDuration(s) {
        s = Math.round(s);
        if (s < 60) { return s + ' s'; }
        const m = Math.floor(s / 60);
        return m < 60 ? m + ' min ' + (s % 60) + ' s' : Math.floor(m / 60) + ' h ' + (m % 60) + ' min';
    }
    function showError(msg) { $('#sl-error').text(msg).toggle(!!msg); }
    function showMessage(msg) {
        $('#sl-message').text(msg).show();
        setTimeout(() => $('#sl-message').fadeOut(), 6000);
    }
    function setTile(id, cls) { $(id).removeClass('sl-ok sl-info sl-warn sl-bad').addClass(cls || ''); }
    function kv(rows) {
        return rows.map(r => '<dt>' + esc(r[0]) + '</dt><dd>' + esc(r[1] == null || r[1] === '' ? DASH : r[1]) + '</dd>').join('');
    }
    function stateClass(state) { return state === 'CONNECTED' ? 'sl-ok' : (state === 'SLEEPING' ? 'sl-info' : 'sl-bad'); }

    // --------------------------------------------------------------- updates
    let fwReady = false, pluginInfo = null, autoChecked = false;
    function refreshBadge() {
        $('#sl-upd-badge').toggle(fwReady || !!(pluginInfo && pluginInfo.available));
    }
    function renderFirmware(u) {
        fwReady = !!u.ready;
        let text;
        if (u.ready) { text = 'Update ready – installs when the dish reboots'; }
        else if (u.in_progress) { text = 'Downloading / installing' + (u.progress != null ? ' (' + Math.round(u.progress * 100) + '%)' : '') + '…'; }
        else if (u.state === 'FAULTED') { text = 'Last update failed'; }
        else if (u.state === 'DISABLED') { text = 'Updates are disabled on the dish'; }
        else { text = 'Up to date' + (u.state ? ' (' + u.state.toLowerCase().replace(/_/g, ' ') + ')' : ''); }
        $('#sl-fw-state').text(text);
        $('#sl-btn-fw-update').toggle(fwReady);
        refreshBadge();
    }
    function renderPlugin(p) {
        pluginInfo = p;
        if (!p) { return; }
        let text;
        if (!p.installed) { text = 'Version unknown (latest ' + p.latest + ')'; }
        else if (p.available) { text = 'v' + p.installed + ' → v' + p.latest + ' available' + (p.pkg_managed ? ' (update under System → Firmware)' : ''); }
        else { text = 'v' + p.installed + ' (up to date)'; }
        $('#sl-pl-state').text(text);
        $('#sl-btn-pl-update').toggle(!!p.available && !p.pkg_managed);
        refreshBadge();
    }
    function checkPlugin() {
        $('#sl-pl-state').text('checking…');
        ajaxGet('/api/starlink/dish/pluginCheck', {}, function (data) {
            if (data && data.ok) { renderPlugin(data); }
            else { $('#sl-pl-state').text((data && data.error) || 'check failed'); }
        });
    }
    $('#sl-btn-check').click(function () { loadStatus(); checkPlugin(); });
    $('#sl-btn-fw-update').click(function () { action('/api/starlink/dish/reboot', {}, T.fwUpdate, $(this)); });
    $('#sl-btn-pl-update').click(function () { action('/api/starlink/dish/pluginUpdate', {}, T.plUpdate, $(this)); });

    // ---------------------------------------------------------------- status
    function renderStatus(d) {
        lastStatus = d;
        $('#sl-pill').removeClass('sl-ok sl-info sl-bad').addClass(stateClass(d.state));
        $('#sl-state').text(d.state.replace(/_/g, ' '));
        const model = d.model ? d.model.name : '';
        $('#sl-headmeta').text([model, 'up ' + fmtUptime(d.uptime_s), d.transport ? 'via ' + d.transport : ''].filter(Boolean).join('  ·  '));
        $('#sl-updated').text('updated ' + new Date().toLocaleTimeString());

        const lat = d.latency_ms || 0, drop = d.drop_rate * 100, obs = d.obstruction.fraction_obstructed * 100;
        $('#sl-latency').html(lat ? esc(lat) + '<span class="sl-unit">ms</span>' : DASH);
        setTile('#sl-t-latency', !lat ? '' : (lat < 60 ? 'sl-ok' : (lat < 120 ? 'sl-warn' : 'sl-bad')));
        $('#sl-drop').text(drop.toFixed(2) + '% packet loss');
        $('#sl-down').html(esc(d.downlink_mbps) + '<span class="sl-unit">Mbps</span>');
        $('#sl-up').html(esc(d.uplink_mbps) + '<span class="sl-unit">Mbps</span>');
        $('#sl-obs').html(obs.toFixed(2) + '<span class="sl-unit">%</span>');
        setTile('#sl-t-obs', obs < 1 ? 'sl-ok' : (obs < 5 ? 'sl-warn' : 'sl-bad'));
        $('#sl-obs-sub').text(d.obstruction.currently_obstructed ? 'obstructed now' : 'clear now');

        const s = d.sleep || {};
        $('#sl-sleep-current').text(s.enabled ? (s.start_local + ' – ' + s.end_local + ' (local)') : T.noSchedule);
        const m = d.managed_schedule || {};
        $('#sl-sleep-managed').text(m.enabled ? (T.yes + ': ' + m.start + ' – ' + m.end) : T.no);
        const h = d.wake_hold;
        $('#sl-sleep-hold').text(!h ? T.none : (h.indefinite ? 'awake until resumed' : 'awake until ' + h.until_local));
        $('#sl-direct-sleep').toggle(!m.enabled);
        $('#sl-managed-note').toggle(!!m.enabled);
        if (s.enabled && !$('#sl-sleep-start').is(':focus') && !$('#sl-sleep-end').is(':focus')) {
            $('#sl-sleep-start').val(s.start_local);
            $('#sl-sleep-end').val(s.end_local);
        }
        const snow = {AUTO: 'auto', ALWAYS_ON: 'on', ALWAYS_OFF: 'off'}[d.snow_melt_mode] || 'auto';
        if (!$('#sl-snowmelt').is(':focus')) { $('#sl-snowmelt').val(snow); }
        // show only the features the dish model supports (all features if the backend sent none)
        const feats = d.model && d.model.features;
        $('[data-feature]').each(function () {
            $(this).toggle(!feats || feats.indexOf($(this).data('feature')) !== -1);
        });

        const rows = [
            ['Model', d.model ? d.model.name + (d.model.selected === 'auto' ? ' (detected)' : '') : null],
            ['Hardware', d.device.hardware_version], ['Software', d.device.software_version],
            ['Software update', d.software_update_state], ['ID', d.device.id], ['Country', d.device.country_code],
            ['Boot count', d.device.bootcount], ['Ethernet speed', d.eth_speed_mbps ? d.eth_speed_mbps + ' Mbps' : null],
            ['GPS', d.gps.inhibited ? 'disabled' : (d.gps.valid ? 'valid, ' + d.gps.sats + ' sats' : 'no fix')],
            ['Pointing (az / el)', (d.azimuth_deg ?? DASH) + '° / ' + (d.elevation_deg ?? DASH) + '°'],
            ['Tilt', d.tilt_angle_deg != null ? d.tilt_angle_deg + '°' : null],
            ['Snow melt', d.snow_melt_mode],
        ];
        if (d.outage) { rows.unshift(['Outage cause', d.outage.cause]); }
        renderFirmware(d.update || {});
        $('#sl-details').html(kv(rows));
        $('#sl-alerts').html(d.alerts.length
            ? d.alerts.map(a => '<span class="sl-chip ' + (a === 'is_heating' || a === 'is_power_save_idle' ? 'sl-info' : 'sl-warn') + '">' + esc(a.replace(/_/g, ' ')) + '</span>').join('')
            : '<span class="sl-empty">' + T.none + '</span>');
    }

    function loadStatus() {
        return ajaxGet('/api/starlink/dish/status', {}, function (data) {
            if (data && data.ok) { showError(''); renderStatus(data); }
            else {
                showError((data && data.error) || 'No response from backend');
                $('#sl-pill').removeClass('sl-ok sl-info').addClass('sl-bad');
                $('#sl-state').text('UNREACHABLE');
            }
        });
    }

    function action(url, payload, confirmMsg, $btn) {
        const go = function () {
            if ($btn) { $btn.addClass('sl-busy'); }
            ajaxCall(url, payload || {}, function (data) {
                if ($btn) { $btn.removeClass('sl-busy'); }
                if (data && data.ok) { showError(''); showMessage(data.message || 'Done'); }
                else { showError((data && data.error) || 'Request failed'); }
                setTimeout(loadStatus, 1500);
            });
        };
        if (confirmMsg) { stdDialogConfirm(T.confirm, confirmMsg, T.yes, T.no, go, 'warning'); } else { go(); }
    }

    $('#sl-btn-refresh').click(loadStatus);
    $('#sl-btn-wake').click(function () { action('/api/starlink/dish/wake', {hours: $('#sl-wake-hours').val()}, null, $(this)); });
    $('#sl-btn-resume').click(function () { action('/api/starlink/dish/resume', {}, null, $(this)); });
    $('#sl-btn-sleep-set').click(function () { action('/api/starlink/dish/sleep', {mode: 'set', start: $('#sl-sleep-start').val(), end: $('#sl-sleep-end').val()}, null, $(this)); });
    $('#sl-btn-sleep-off').click(function () { action('/api/starlink/dish/sleep', {mode: 'off'}, T.sleepOff, $(this)); });
    $('#sl-btn-reboot').click(function () { action('/api/starlink/dish/reboot', {}, T.reboot, $(this)); });
    $('#sl-btn-stow').click(function () { action('/api/starlink/dish/stow', {}, T.stow, $(this)); });
    $('#sl-btn-unstow').click(function () { action('/api/starlink/dish/unstow', {}, null, $(this)); });
    $('#sl-btn-gps').click(function () {
        const on = lastStatus && lastStatus.gps.inhibited;
        action('/api/starlink/dish/gps', {state: on ? 'on' : 'off'}, on ? null : "{{ lang._('Disable GPS on the dish? It falls back to Starlink positioning. GPS is re-enabled when the dish reboots.') }}", $(this));
    });
    $('#sl-btn-snowmelt').click(function () { action('/api/starlink/dish/snowmelt', {mode: $('#sl-snowmelt').val()}, null, $(this)); });

    // --------------------------------------------------------------- charts
    const charts = {};
    function drawChart(id, seriesList, opts) {
        const c = document.getElementById(id);
        const w = c.clientWidth, h = c.clientHeight, dpr = window.devicePixelRatio || 1;
        c.width = w * dpr; c.height = h * dpr;
        const g = c.getContext('2d'); g.scale(dpr, dpr); g.clearRect(0, 0, w, h);
        const fg = getComputedStyle(document.body).color || '#888';
        const left = 44, right = 8, top = 6, bottom = 18, pw = w - left - right, ph = h - top - bottom;
        let max = 0;
        seriesList.forEach(s => s.data.forEach(v => { if (v > max) max = v; }));
        max = max > 0 ? max * 1.1 : 1;
        if (opts.minMax && max < opts.minMax) { max = opts.minMax; }
        const n = Math.max(0, ...seriesList.map(s => s.data.length));
        const X = i => left + (n > 1 ? pw * i / (n - 1) : 0);
        const Y = v => top + ph - ph * Math.min(v, max) / max;
        g.font = '10px sans-serif'; g.fillStyle = fg; g.lineWidth = 1;
        for (let i = 0; i <= 4; i++) {
            const y = top + ph - ph * i / 4;
            g.strokeStyle = 'rgba(128,128,128,.22)';
            g.beginPath(); g.moveTo(left, y); g.lineTo(left + pw, y); g.stroke();
            g.globalAlpha = .7; g.fillText((max * i / 4).toFixed(max < 5 ? 2 : 0), 2, y + 3); g.globalAlpha = 1;
        }
        g.globalAlpha = .7;
        g.fillText('-' + opts.rangeLabel, left, h - 4);
        g.fillText('now', left + pw - 20, h - 4);
        g.globalAlpha = 1;
        seriesList.forEach((s, si) => {
            if (!s.data.length) { return; }
            if (si === 0) {   // light fill under the first series
                g.beginPath(); g.moveTo(X(0), top + ph);
                s.data.forEach((v, i) => g.lineTo(X(i), Y(v)));
                g.lineTo(X(s.data.length - 1), top + ph); g.closePath();
                g.globalAlpha = .12; g.fillStyle = s.color; g.fill(); g.globalAlpha = 1;
            }
            g.strokeStyle = s.color; g.lineWidth = 1.6; g.lineJoin = 'round'; g.beginPath();
            s.data.forEach((v, i) => { i ? g.lineTo(X(i), Y(v)) : g.moveTo(X(i), Y(v)); });
            g.stroke();
        });
        charts[id] = {seriesList, opts, n, left, pw, redraw: () => drawChart(id, seriesList, opts)};
    }
    function stats(data, unit, digits) {
        if (!data.length) { return ''; }
        const min = Math.min(...data), max = Math.max(...data), avg = data.reduce((a, b) => a + b, 0) / data.length;
        return 'min ' + min.toFixed(digits) + ' · avg ' + avg.toFixed(digits) + ' · max ' + max.toFixed(digits) + ' ' + unit;
    }
    // hover tooltip: shows the value(s) under the pointer
    $('.sl-chart').on('mousemove', function (e) {
        const ch = charts[this.id], $tip = $(this).siblings('.sl-tip');
        if (!ch || ch.n < 2) { return; }
        const rect = this.getBoundingClientRect(), x = e.clientX - rect.left;
        const i = Math.max(0, Math.min(ch.n - 1, Math.round((x - ch.left) / ch.pw * (ch.n - 1))));
        const secs = $('#sl-hist-range').val() * (1 - i / (ch.n - 1));
        const vals = ch.seriesList.map(s => s.data[i] == null ? DASH : Number(s.data[i]).toFixed(2)).join(' / ');
        $tip.text(vals + ' ' + (ch.opts.unit || '') + '  ·  ' + fmtDuration(secs) + ' ago')
            .css({left: Math.min(x + 12, rect.width - 160), top: 8}).show();
    }).on('mouseleave', function () { $(this).siblings('.sl-tip').hide(); });

    let lastHistory = null;
    function renderHistory() {
        const d = lastHistory; if (!d) { return; }
        const label = $('#sl-hist-range option:selected').text().replace(/^Last /i, '');
        const loss = d.series.drop_rate.map(v => v * 100);
        drawChart('sl-c-latency', [{data: d.series.latency_ms, color: '#5cb85c'}], {rangeLabel: label, minMax: 50, unit: 'ms'});
        drawChart('sl-c-drop', [{data: loss, color: '#d9534f'}], {rangeLabel: label, minMax: 1, unit: '%'});
        drawChart('sl-c-tput', [{data: d.series.downlink_mbps, color: '#2f7ed8'}, {data: d.series.uplink_mbps, color: '#e4a32e'}], {rangeLabel: label, minMax: 5, unit: 'Mbps (down / up)'});
        drawChart('sl-c-power', [{data: d.series.power_w, color: '#9b59b6'}], {rangeLabel: label, minMax: 10, unit: 'W'});
        $('#sl-s-latency').text(stats(d.series.latency_ms, 'ms', 1));
        $('#sl-s-drop').text(stats(loss, '%', 2));
        $('#sl-s-power').text(stats(d.series.power_w, 'W', 1));
        $('#sl-hist-note').text(fmtDuration(d.seconds) + ' of data');
        $('#sl-outages').html(d.outages.length ? d.outages.map(o =>
            '<tr><td>' + esc(o.start_local) + '</td><td>' + esc(o.cause.replace(/_/g, ' ')) + '</td><td>' + esc(fmtDuration(o.duration_s)) + '</td></tr>').join('')
            : '<tr><td colspan="3" class="text-muted">' + T.none + '</td></tr>');
    }
    function loadHistory() {
        $('#sl-hist-note').text('loading…');
        ajaxGet('/api/starlink/dish/history', {seconds: $('#sl-hist-range').val()}, function (data) {
            if (data && data.ok) { lastHistory = data; renderHistory(); }
            else { $('#sl-hist-note').text((data && data.error) || 'failed'); }
        });
    }
    $('#sl-btn-hist').click(loadHistory);
    $('#sl-hist-range').change(loadHistory);
    $(window).on('resize', renderHistory);

    // ---------------------------------------------------------- obstruction
    function loadObstruction() {
        ajaxGet('/api/starlink/dish/obstruction', {}, function (d) {
            if (!d || !d.ok) { $('#sl-obs-details').html('<dt>Error</dt><dd>' + esc(d && d.error) + '</dd>'); return; }
            const c = document.getElementById('sl-obsmap');
            c.width = d.cols; c.height = d.rows;
            const g = c.getContext('2d'), img = g.createImageData(d.cols, d.rows);
            let seen = 0, bad = 0;
            d.snr.forEach((v, i) => {
                const p = i * 4;
                if (v < 0) { img.data[p + 3] = 0; return; }
                seen++; if (v < 0.5) { bad++; }
                img.data[p] = Math.round(255 * (1 - v)); img.data[p + 1] = Math.round(200 * v); img.data[p + 2] = 40; img.data[p + 3] = 255;
            });
            g.putImageData(img, 0, 0);
            const rows = [['Map size', d.cols + ' × ' + d.rows], ['Reference frame', d.frame],
                ['Min elevation', d.min_elevation_deg + '°'], ['Observed cells', seen],
                ['Obstructed cells', seen ? bad + ' (' + (bad / seen * 100).toFixed(1) + '%)' : null]];
            if (lastStatus) { rows.push(['Fraction obstructed (dish)', (lastStatus.obstruction.fraction_obstructed * 100).toFixed(2) + '%']); }
            $('#sl-obs-details').html(kv(rows));
        });
    }
    $('#sl-btn-obs').click(loadObstruction);

    // ------------------------------------------------------------- settings
    function loadSettings() {
        return mapDataToFormUI({'frm_general': '/api/starlink/settings/get', 'frm_schedule': '/api/starlink/settings/get'}).done(function (data) {
            $('.selectpicker').selectpicker('refresh');
            const general = (((data.frm_general || {}).starlink || {}).general || {});
            if (general.update_check === '1' && !autoChecked) { autoChecked = true; checkPlugin(); }
            const sec = parseInt(general.refresh, 10);
            if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null; }
            if (sec > 0) {
                refreshTimer = setInterval(function () { if ($('#tab-status').hasClass('active') && !document.hidden) { loadStatus(); } }, sec * 1000);
            }
        });
    }
    $('#sl-btn-save').click(function () {
        $('#sl-save-progress').addClass('fa fa-spinner fa-pulse');
        saveFormToEndpoint('/api/starlink/settings/set', 'frm_general', function () {
            saveFormToEndpoint('/api/starlink/settings/set', 'frm_schedule', function () {
                ajaxCall('/api/starlink/dish/resync', {}, function (r) {
                    $('#sl-save-progress').removeClass('fa fa-spinner fa-pulse');
                    if (r && !r.ok) { showError(r.error); }
                    loadSettings(); loadStatus();
                });
            }, true, function () { $('#sl-save-progress').removeClass('fa fa-spinner fa-pulse'); });
        }, true, function () { $('#sl-save-progress').removeClass('fa fa-spinner fa-pulse'); });
    });

    // ------------------------------------------------------------------ tabs
    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        const t = $(e.target).attr('href');
        if (t === '#tab-history') { lastHistory ? renderHistory() : loadHistory(); }
        if (t === '#tab-obstruction') { loadObstruction(); }
        if (t === '#tab-status') { loadStatus(); }
        if (window.history && history.replaceState) { history.replaceState(null, '', t); }
    });
    if (window.location.hash && $('a[href="' + window.location.hash + '"]').length) {
        $('a[href="' + window.location.hash + '"]').tab('show');
    }

    loadSettings();
    loadStatus();
});
</script>
