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
    .sl-tiles { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 15px; }
    .sl-tile { flex: 1 1 150px; border: 1px solid rgba(128,128,128,.25); border-radius: 4px; padding: 10px 12px; }
    .sl-tile .sl-label { font-size: 11px; text-transform: uppercase; opacity: .7; }
    .sl-tile .sl-value { font-size: 22px; font-weight: 600; }
    .sl-tile .sl-sub { font-size: 12px; opacity: .75; }
    .sl-state-CONNECTED { color: #3c9a3c; }
    .sl-state-SLEEPING { color: #4a7fc1; }
    .sl-state-other { color: #c9302c; }
    .sl-chart { width: 100%; height: 170px; display: block; }
    .sl-chart-title { font-weight: 600; margin: 12px 0 4px; }
    #sl-obsmap { max-width: 100%; image-rendering: pixelated; border: 1px solid rgba(128,128,128,.3); border-radius: 50%; }
    .sl-actions .btn { margin: 0 6px 6px 0; }
    .sl-msg { margin: 10px 0; }
    .sl-section { padding: 10px 15px; }
    table.sl-kv td:first-child { width: 220px; opacity: .8; }
</style>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab-status">{{ lang._('Status') }}</a></li>
    <li><a data-toggle="tab" href="#tab-history">{{ lang._('History') }}</a></li>
    <li><a data-toggle="tab" href="#tab-obstruction">{{ lang._('Obstructions') }}</a></li>
    <li><a data-toggle="tab" href="#tab-settings">{{ lang._('Settings') }}</a></li>
</ul>

<div class="tab-content content-box">
    <!-- STATUS -->
    <div id="tab-status" class="tab-pane fade in active sl-section">
        <div id="sl-error" class="alert alert-danger sl-msg" style="display:none"></div>
        <div id="sl-message" class="alert alert-info sl-msg" style="display:none"></div>

        <div class="sl-tiles">
            <div class="sl-tile"><div class="sl-label">{{ lang._('State') }}</div><div class="sl-value" id="sl-state">&hellip;</div><div class="sl-sub" id="sl-uptime"></div></div>
            <div class="sl-tile"><div class="sl-label">{{ lang._('Latency') }}</div><div class="sl-value" id="sl-latency">&ndash;</div><div class="sl-sub" id="sl-drop"></div></div>
            <div class="sl-tile"><div class="sl-label">{{ lang._('Download') }}</div><div class="sl-value" id="sl-down">&ndash;</div><div class="sl-sub">{{ lang._('current') }}</div></div>
            <div class="sl-tile"><div class="sl-label">{{ lang._('Upload') }}</div><div class="sl-value" id="sl-up">&ndash;</div><div class="sl-sub">{{ lang._('current') }}</div></div>
            <div class="sl-tile"><div class="sl-label">{{ lang._('Obstructed') }}</div><div class="sl-value" id="sl-obs">&ndash;</div><div class="sl-sub" id="sl-obs-sub"></div></div>
        </div>

        <div class="row">
            <div class="col-md-6">
                <h3>{{ lang._('Sleep schedule') }}</h3>
                <table class="table table-condensed sl-kv">
                    <tr><td>{{ lang._('Dish schedule') }}</td><td id="sl-sleep-current">&ndash;</td></tr>
                    <tr><td>{{ lang._('Managed by OPNsense') }}</td><td id="sl-sleep-managed">&ndash;</td></tr>
                    <tr><td>{{ lang._('Wake override') }}</td><td id="sl-sleep-hold">&ndash;</td></tr>
                </table>
                <div class="sl-actions">
                    <div class="form-inline" style="margin-bottom:8px">
                        <select id="sl-wake-hours" class="form-control" style="width:auto">
                            <option value="1">{{ lang._('for 1 hour') }}</option>
                            <option value="2" selected>{{ lang._('for 2 hours') }}</option>
                            <option value="4">{{ lang._('for 4 hours') }}</option>
                            <option value="8">{{ lang._('for 8 hours') }}</option>
                            <option value="24">{{ lang._('for 24 hours') }}</option>
                            <option value="0">{{ lang._('until I resume') }}</option>
                        </select>
                        <button class="btn btn-primary" id="sl-btn-wake"><i class="fa fa-sun-o fa-sun fa-fw"></i> {{ lang._('Wake now') }}</button>
                        <button class="btn btn-default" id="sl-btn-resume"><i class="fa fa-moon-o fa-moon fa-fw"></i> {{ lang._('Resume schedule') }}</button>
                    </div>
                    <div class="form-inline" id="sl-direct-sleep">
                        <input type="time" class="form-control" id="sl-sleep-start" value="01:00" style="width:auto">
                        <span>&nbsp;{{ lang._('to') }}&nbsp;</span>
                        <input type="time" class="form-control" id="sl-sleep-end" value="06:00" style="width:auto">
                        <button class="btn btn-default" id="sl-btn-sleep-set">{{ lang._('Apply to dish') }}</button>
                        <button class="btn btn-default" id="sl-btn-sleep-off">{{ lang._('Disable sleep') }}</button>
                    </div>
                    <p class="text-muted" id="sl-managed-note" style="display:none; margin-top:6px">
                        {{ lang._('The schedule is managed by OPNsense. Change it on the Settings tab.') }}
                    </p>
                </div>

                <h3>{{ lang._('Controls') }}</h3>
                <div class="sl-actions">
                    <button class="btn btn-warning" id="sl-btn-reboot"><i class="fa fa-refresh fa-fw"></i> {{ lang._('Reboot dish') }}</button>
                    <button class="btn btn-default sl-actuator" id="sl-btn-stow">{{ lang._('Stow') }}</button>
                    <button class="btn btn-default sl-actuator" id="sl-btn-unstow">{{ lang._('Unstow') }}</button>
                    <button class="btn btn-default" id="sl-btn-gps">{{ lang._('Toggle GPS') }}</button>
                </div>
                <div class="form-inline" style="margin-top:4px">
                    <label for="sl-snowmelt">{{ lang._('Snow melt') }}&nbsp;</label>
                    <select id="sl-snowmelt" class="form-control" style="width:auto">
                        <option value="auto">{{ lang._('Automatic') }}</option>
                        <option value="on">{{ lang._('Always on') }}</option>
                        <option value="off">{{ lang._('Always off') }}</option>
                    </select>
                    <button class="btn btn-default" id="sl-btn-snowmelt">{{ lang._('Apply') }}</button>
                </div>
            </div>
            <div class="col-md-6">
                <h3>{{ lang._('Dish') }}</h3>
                <table class="table table-condensed sl-kv" id="sl-details"></table>
                <h3>{{ lang._('Active alerts') }}</h3>
                <div id="sl-alerts" class="text-muted">&ndash;</div>
            </div>
        </div>
    </div>

    <!-- HISTORY -->
    <div id="tab-history" class="tab-pane fade sl-section">
        <div class="form-inline">
            <select id="sl-hist-range" class="form-control" style="width:auto">
                <option value="900">{{ lang._('Last 15 minutes') }}</option>
                <option value="3600" selected>{{ lang._('Last hour') }}</option>
                <option value="21600">{{ lang._('Last 6 hours') }}</option>
                <option value="43200">{{ lang._('Last 12 hours') }}</option>
            </select>
            <button class="btn btn-default" id="sl-btn-hist"><i class="fa fa-refresh fa-fw"></i> {{ lang._('Refresh') }}</button>
            <span class="text-muted" id="sl-hist-note"></span>
        </div>
        <div class="sl-chart-title">{{ lang._('Latency (ms)') }}</div><canvas class="sl-chart" id="sl-c-latency"></canvas>
        <div class="sl-chart-title">{{ lang._('Packet loss (%)') }}</div><canvas class="sl-chart" id="sl-c-drop"></canvas>
        <div class="sl-chart-title">{{ lang._('Throughput (Mbps)') }} <small><span style="color:#2f7ed8">&#9632;</span> {{ lang._('down') }} <span style="color:#e4a32e">&#9632;</span> {{ lang._('up') }}</small></div><canvas class="sl-chart" id="sl-c-tput"></canvas>
        <div class="sl-chart-title">{{ lang._('Power draw (W)') }}</div><canvas class="sl-chart" id="sl-c-power"></canvas>
        <h3>{{ lang._('Recent outages') }}</h3>
        <table class="table table-condensed table-striped">
            <thead><tr><th>{{ lang._('Start') }}</th><th>{{ lang._('Cause') }}</th><th>{{ lang._('Duration') }}</th></tr></thead>
            <tbody id="sl-outages"><tr><td colspan="3" class="text-muted">&ndash;</td></tr></tbody>
        </table>
    </div>

    <!-- OBSTRUCTION -->
    <div id="tab-obstruction" class="tab-pane fade sl-section">
        <button class="btn btn-default" id="sl-btn-obs"><i class="fa fa-refresh fa-fw"></i> {{ lang._('Refresh') }}</button>
        <div class="row" style="margin-top:12px">
            <div class="col-md-6"><canvas id="sl-obsmap" width="123" height="123" style="width:100%; max-width:480px"></canvas></div>
            <div class="col-md-6">
                <p>{{ lang._('Sky view as seen by the dish: the centre is straight up and the edge is the lowest elevation the dish uses. Green = clear sky observed, red = obstructed, blank = not yet observed. The map builds up over about 12 hours.') }}</p>
                <table class="table table-condensed sl-kv" id="sl-obs-details"></table>
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
    };
    let lastStatus = null;
    let refreshTimer = null;

    function esc(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }
    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + 'd ' : '') + h + 'h ' + m + 'm';
    }
    function showError(msg) { $('#sl-error').text(msg).toggle(!!msg); }
    function showMessage(msg) {
        $('#sl-message').text(msg).show();
        setTimeout(() => $('#sl-message').fadeOut(), 6000);
    }

    // ---------------------------------------------------------------- status
    function renderStatus(d) {
        lastStatus = d;
        const stateCls = ['CONNECTED', 'SLEEPING'].includes(d.state) ? 'sl-state-' + d.state : 'sl-state-other';
        $('#sl-state').attr('class', 'sl-value ' + stateCls).text(d.state.replace(/_/g, ' '));
        $('#sl-uptime').text('up ' + fmtUptime(d.uptime_s));
        $('#sl-latency').text(d.latency_ms ? d.latency_ms + ' ms' : '\u2013');
        $('#sl-drop').text((d.drop_rate * 100).toFixed(2) + '% drop');
        $('#sl-down').text(d.downlink_mbps + ' Mbps');
        $('#sl-up').text(d.uplink_mbps + ' Mbps');
        $('#sl-obs').text((d.obstruction.fraction_obstructed * 100).toFixed(2) + '%');
        $('#sl-obs-sub').text(d.obstruction.currently_obstructed ? 'obstructed now' : 'clear now');

        const s = d.sleep || {};
        $('#sl-sleep-current').text(s.enabled ? (s.start_local + ' \u2013 ' + s.end_local + ' (local)') : T.noSchedule);
        const m = d.managed_schedule || {};
        $('#sl-sleep-managed').text(m.enabled ? (T.yes + ': ' + m.start + ' \u2013 ' + m.end) : T.no);
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
        $('.sl-actuator').toggle(d.has_actuators !== 'HAS_ACTUATORS_NO');

        const rows = [
            ['ID', d.device.id], ['Hardware', d.device.hardware_version], ['Software', d.device.software_version],
            ['Software update', d.software_update_state], ['Country', d.device.country_code],
            ['Boot count', d.device.bootcount], ['Ethernet speed', d.eth_speed_mbps ? d.eth_speed_mbps + ' Mbps' : '\u2013'],
            ['GPS', d.gps.inhibited ? 'disabled' : (d.gps.valid ? 'valid, ' + d.gps.sats + ' sats' : 'no fix')],
            ['Pointing (az / el)', (d.azimuth_deg ?? '\u2013') + '\u00b0 / ' + (d.elevation_deg ?? '\u2013') + '\u00b0'],
            ['Tilt', d.tilt_angle_deg != null ? d.tilt_angle_deg + '\u00b0' : '\u2013'],
            ['Snow melt', d.snow_melt_mode], ['Connection', d.transport],
        ];
        if (d.outage) { rows.unshift(['Outage cause', d.outage.cause]); }
        $('#sl-details').html(rows.map(r => '<tr><td>' + esc(r[0]) + '</td><td>' + esc(r[1] ?? '\u2013') + '</td></tr>').join(''));
        $('#sl-alerts').html(d.alerts.length
            ? d.alerts.map(a => '<span class="label label-' + (a === 'is_heating' || a === 'is_power_save_idle' ? 'info' : 'warning') + '" style="display:inline-block;margin:2px">' + esc(a.replace(/_/g, ' ')) + '</span>').join(' ')
            : T.none);
    }

    function loadStatus() {
        return ajaxGet('/api/starlink/dish/status', {}, function (data) {
            if (data && data.ok) { showError(''); renderStatus(data); }
            else { showError((data && data.error) || 'No response from backend'); $('#sl-state').attr('class', 'sl-value sl-state-other').text('UNREACHABLE'); }
        });
    }

    function action(url, payload, confirmMsg) {
        const go = function () {
            ajaxCall(url, payload || {}, function (data) {
                if (data && data.ok) { showError(''); showMessage(data.message || 'Done'); }
                else { showError((data && data.error) || 'Request failed'); }
                setTimeout(loadStatus, 1500);
            });
        };
        if (confirmMsg) { stdDialogConfirm(T.confirm, confirmMsg, T.yes, T.no, go, 'warning'); } else { go(); }
    }

    $('#sl-btn-wake').click(() => action('/api/starlink/dish/wake', {hours: $('#sl-wake-hours').val()}));
    $('#sl-btn-resume').click(() => action('/api/starlink/dish/resume'));
    $('#sl-btn-sleep-set').click(() => action('/api/starlink/dish/sleep', {mode: 'set', start: $('#sl-sleep-start').val(), end: $('#sl-sleep-end').val()}));
    $('#sl-btn-sleep-off').click(() => action('/api/starlink/dish/sleep', {mode: 'off'}, T.sleepOff));
    $('#sl-btn-reboot').click(() => action('/api/starlink/dish/reboot', {}, T.reboot));
    $('#sl-btn-stow').click(() => action('/api/starlink/dish/stow', {}, T.stow));
    $('#sl-btn-unstow').click(() => action('/api/starlink/dish/unstow'));
    $('#sl-btn-gps').click(function () {
        const on = lastStatus && lastStatus.gps.inhibited;
        action('/api/starlink/dish/gps', {state: on ? 'on' : 'off'}, on ? null : "{{ lang._('Disable GPS on the dish? It falls back to Starlink positioning. GPS is re-enabled when the dish reboots.') }}");
    });
    $('#sl-btn-snowmelt').click(() => action('/api/starlink/dish/snowmelt', {mode: $('#sl-snowmelt').val()}));

    // --------------------------------------------------------------- charts
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
        g.font = '10px sans-serif'; g.fillStyle = fg; g.strokeStyle = 'rgba(128,128,128,.25)'; g.lineWidth = 1;
        for (let i = 0; i <= 4; i++) {
            const y = top + ph - ph * i / 4;
            g.beginPath(); g.moveTo(left, y); g.lineTo(left + pw, y); g.stroke();
            g.fillText((max * i / 4).toFixed(max < 5 ? 2 : 0), 2, y + 3);
        }
        const n = Math.max(...seriesList.map(s => s.data.length));
        g.fillText('-' + opts.rangeLabel, left, h - 4);
        g.fillText('now', left + pw - 20, h - 4);
        seriesList.forEach(s => {
            g.strokeStyle = s.color; g.lineWidth = 1.5; g.beginPath();
            s.data.forEach((v, i) => {
                const x = left + (n > 1 ? pw * i / (n - 1) : 0), y = top + ph - ph * Math.min(v, max) / max;
                i ? g.lineTo(x, y) : g.moveTo(x, y);
            });
            g.stroke();
        });
    }

    let lastHistory = null;
    function renderHistory() {
        const d = lastHistory; if (!d) { return; }
        const label = $('#sl-hist-range option:selected').text().replace(/^Last /i, '');
        drawChart('sl-c-latency', [{data: d.series.latency_ms, color: '#5cb85c'}], {rangeLabel: label, minMax: 50});
        drawChart('sl-c-drop', [{data: d.series.drop_rate.map(v => v * 100), color: '#d9534f'}], {rangeLabel: label, minMax: 1});
        drawChart('sl-c-tput', [{data: d.series.downlink_mbps, color: '#2f7ed8'}, {data: d.series.uplink_mbps, color: '#e4a32e'}], {rangeLabel: label, minMax: 5});
        drawChart('sl-c-power', [{data: d.series.power_w, color: '#9b59b6'}], {rangeLabel: label, minMax: 10});
        $('#sl-hist-note').text(d.seconds + ' s of data');
        $('#sl-outages').html(d.outages.length ? d.outages.map(o =>
            '<tr><td>' + esc(o.start_local) + '</td><td>' + esc(o.cause.replace(/_/g, ' ')) + '</td><td>' + esc(o.duration_s) + ' s</td></tr>').join('')
            : '<tr><td colspan="3" class="text-muted">' + T.none + '</td></tr>');
    }
    function loadHistory() {
        $('#sl-hist-note').text('loading\u2026');
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
            if (!d || !d.ok) { $('#sl-obs-details').html('<tr><td colspan="2">' + esc(d && d.error) + '</td></tr>'); return; }
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
            const rows = [['Map size', d.cols + ' \u00d7 ' + d.rows], ['Reference frame', d.frame],
                ['Min elevation', d.min_elevation_deg + '\u00b0'], ['Observed cells', seen],
                ['Obstructed cells', seen ? bad + ' (' + (bad / seen * 100).toFixed(1) + '%)' : '\u2013']];
            if (lastStatus) { rows.push(['Fraction obstructed (dish)', (lastStatus.obstruction.fraction_obstructed * 100).toFixed(2) + '%']); }
            $('#sl-obs-details').html(rows.map(r => '<tr><td>' + esc(r[0]) + '</td><td>' + esc(r[1]) + '</td></tr>').join(''));
        });
    }
    $('#sl-btn-obs').click(loadObstruction);

    // ------------------------------------------------------------- settings
    function loadSettings() {
        return mapDataToFormUI({'frm_general': '/api/starlink/settings/get', 'frm_schedule': '/api/starlink/settings/get'}).done(function (data) {
            $('.selectpicker').selectpicker('refresh');
            const sec = parseInt((((data.frm_general || {}).starlink || {}).general || {}).refresh, 10);
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
