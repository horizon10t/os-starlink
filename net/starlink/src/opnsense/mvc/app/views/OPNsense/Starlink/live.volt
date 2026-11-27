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
    .sl-live { padding: 14px 18px 18px; }
    .sl-bar-top { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 14px; margin-bottom: 12px; }
    .sl-bar-top label { margin: 0; font-weight: 400; }
    .sl-bar-top select.form-control { width: auto; min-width: 170px; padding-right: 30px; }
    .sl-bar-top .sl-spacer { flex: 1 1 auto; }
    .sl-layout { display: flex; flex-wrap: wrap; gap: 16px; align-items: flex-start; }
    .sl-mapwrap { flex: 4 1 520px; min-width: 0; }
    #sl-map { display: block; width: 100%; cursor: grab; touch-action: none; border-radius: 6px; background: #03050a; }
    #sl-map.sl-drag { cursor: grabbing; }
    .sl-side { flex: 1 1 260px; min-width: 0; }
    .sl-box { border: 1px solid rgba(128,128,128,.28); border-radius: 6px; padding: 10px 14px; margin-bottom: 14px; }
    .sl-box h4 { margin: 0 0 8px; font-size: 12px; text-transform: uppercase; letter-spacing: .06em; opacity: .8; }
    .sl-box dl { display: grid; grid-template-columns: 90px 1fr; gap: 4px 10px; margin: 0; }
    .sl-box dt { font-weight: 400; opacity: .65; }
    .sl-box dd { margin: 0; }
    .sl-pick { display: flex; justify-content: space-between; gap: 8px; padding: 5px 0; cursor: pointer; border-bottom: 1px solid rgba(128,128,128,.15); }
    .sl-pick.sl-near { color: #3c9a3c; font-weight: 600; }
    .sl-pick.sl-sel { background: rgba(224,160,48,.18); }
    .sl-note { font-size: 12px; opacity: .65; margin: 8px 0 0; }
</style>

<div class="content-box sl-live">
    <div id="sl-live-msg" class="alert alert-info">{{ lang._('Loading satellite data...') }}</div>
    <div id="sl-live-body" style="display:none">
        <div class="sl-bar-top">
            <div class="btn-group">
                <button class="btn btn-default sl-view" data-view="close">{{ lang._('Close') }}</button>
                <button class="btn btn-default sl-view active" data-view="region">{{ lang._('Region') }}</button>
                <button class="btn btn-default sl-view" data-view="globe">{{ lang._('Globe') }}</button>
            </div>
            <select id="sl-area" class="form-control" title="{{ lang._('Which satellites to show') }}">
                <option value="0">{{ lang._('Overhead only') }}</option>
                <option value="2000" selected>{{ lang._('Within 2000 km') }}</option>
                <option value="3500">{{ lang._('Within 3500 km') }}</option>
            </select>
            <button class="btn btn-default" id="sl-pause"><i class="fa fa-pause fa-fw"></i> <span>{{ lang._('Pause') }}</span></button>
            <label><input type="checkbox" id="sl-names" checked> {{ lang._('Names') }}</label>
            <span class="sl-spacer"></span>
            <span id="sl-clock"></span>
        </div>
        <div class="sl-layout">
            <div class="sl-mapwrap">
                <canvas id="sl-map"></canvas>
                <p class="sl-note">{{ lang._('Drag to turn the globe, scroll to zoom, click a satellite for details and its track. Ringed satellites are overhead now; the dashed circle marks roughly where a satellite must be to count as overhead.') }}</p>
                <p class="sl-note" id="sl-live-age"></p>
            </div>
            <div class="sl-side">
                <div class="sl-box"><h4>{{ lang._('Selected satellite') }}</h4><dl id="sl-detail"></dl></div>
                <div class="sl-box"><h4 id="sl-over-title">{{ lang._('Overhead') }}</h4><div id="sl-over"></div>
                    <p class="sl-note">{{ lang._('Sorted by closeness to where the dish points. The dish does not report which satellite it is using, so the first one is only the nearest, not a confirmed connection.') }}</p></div>
            </div>
        </div>
    </div>
</div>

<script src="/ui/js/starlink/satellite.min.js"></script>
<script src="/ui/js/starlink/skymap.js?v=1.0.3"></script>
<script>
$(function () {
    const RAD = Math.PI / 180, DEG = '°', EARTH_KM = 6371;
    const ZOOM = {close: 2.1, region: 0.82, globe: 0.43};    // globe radius as a share of the smaller canvas side
    // colour by orbital inclination (read from the orbit data)
    const SHELLS = [
        {max: 48, color: '#ff9f43', name: '43' + DEG + ' orbits'},
        {max: 60, color: '#4aa8ff', name: '53' + DEG + ' orbits'},
        {max: 80, color: '#c56cf0', name: '70' + DEG + ' orbits'},
        {max: 181, color: '#ff5d7a', name: 'Polar orbits'},
    ];
    let sky = null, world = [], data = null, minEl = 25, boresight = null;
    let view = null, paused = false, selected = null, tick = 0, positions = [], overhead = [], drawn = [], track = [];
    let clock = new Date();
    const canvas = document.getElementById('sl-map');
    const stars = Array.from({length: 420}, (_, i) => {      // fixed pseudo-random star field
        const r = n => { const x = Math.sin((i + 1) * n) * 43758.5453; return x - Math.floor(x); };
        return {x: r(12.9898), y: r(78.233), a: 0.15 + 0.55 * r(37.719)};
    });

    function esc(s) { return $('<div>').text(s == null ? '' : String(s)).html(); }
    function message(text) { $('#sl-live-msg').text(text).show(); $('#sl-live-body').hide(); }
    function size() {
        const w = canvas.parentNode.clientWidth || 800;
        return {w: w, h: Math.max(400, Math.min(Math.round(w * 0.68), Math.round(window.innerHeight * 0.74)))};
    }
    function setView(name) {
        const lat = sky.location.lat;
        // look down at an angle (centre a little north of the observer) so height above the ground shows
        view = {name: name, zoom: ZOOM[name], lon: sky.location.lon,
            lat: name === 'globe' ? Math.max(-60, Math.min(60, lat * 0.6)) : Math.min(80, lat + (name === 'close' ? 3 : 12))};
        $('.sl-view').removeClass('active').filter('[data-view="' + name + '"]').addClass('active');
    }

    // orthographic projection; alt is the height above the ground in km. z < 0 is the far side.
    function projector(s) {
        const R = Math.min(s.w, s.h) * view.zoom, s0 = Math.sin(view.lat * RAD), c0 = Math.cos(view.lat * RAD);
        const at = function (lat, lon, alt) {
            const k = 1 + (alt || 0) / EARTH_KM, sl = Math.sin(lat * RAD), cl = Math.cos(lat * RAD);
            const d = (lon - view.lon) * RAD, cd = Math.cos(d);
            const x = k * cl * Math.sin(d), y = k * (c0 * sl - s0 * cl * cd), z = k * (s0 * sl + c0 * cl * cd);
            return {x: s.w / 2 + x * R, y: s.h / 2 - y * R, z: z, ux: x, uy: y,
                visible: z > 0 || x * x + y * y > 1};
        };
        at.R = R; at.cx = s.w / 2; at.cy = s.h / 2;
        return at;
    }
    function path(g, P, points, alt) {     // stroke a line on or above the globe, broken where it goes behind
        let pen = false;
        g.beginPath();
        points.forEach(function (p) {
            const q = P(p[1], p[0], p[2] === undefined ? alt : p[2]);
            if (!q.visible) { pen = false; return; }
            if (pen) { g.lineTo(q.x, q.y); } else { g.moveTo(q.x, q.y); pen = true; }
        });
        g.stroke();
    }

    function drawSpace(g, s, P) {
        g.fillStyle = '#03050a'; g.fillRect(0, 0, s.w, s.h);
        stars.forEach(function (st) {
            g.fillStyle = 'rgba(255,255,255,' + st.a + ')';
            g.fillRect(st.x * s.w, st.y * s.h, 1.2, 1.2);
        });
        const R = P.R;
        let glow = g.createRadialGradient(P.cx, P.cy, R * 0.97, P.cx, P.cy, R * 1.09);
        glow.addColorStop(0, 'rgba(80,160,255,.55)'); glow.addColorStop(1, 'rgba(80,160,255,0)');
        g.fillStyle = glow; g.beginPath(); g.arc(P.cx, P.cy, R * 1.09, 0, Math.PI * 2); g.fill();
        const sea = g.createRadialGradient(P.cx - R * 0.35, P.cy - R * 0.4, R * 0.1, P.cx, P.cy, R);
        sea.addColorStop(0, '#17406b'); sea.addColorStop(0.65, '#0c2746'); sea.addColorStop(1, '#071526');
        g.fillStyle = sea; g.beginPath(); g.arc(P.cx, P.cy, R, 0, Math.PI * 2); g.fill();
    }
    function drawEarth(g, P) {
        g.save();
        g.beginPath(); g.arc(P.cx, P.cy, P.R, 0, Math.PI * 2); g.clip();
        g.fillStyle = '#2c4a34'; g.strokeStyle = 'rgba(190,215,190,.45)'; g.lineWidth = 0.8;
        world.forEach(function (ring) {
            let any = false;
            const pts = ring.points.map(function (p) {
                const q = P(p[1], p[0], 0);
                if (q.z > 0) { any = true; return q; }
                const n = Math.hypot(q.ux, q.uy) || 1;       // behind the horizon: pull onto the edge
                return {x: P.cx + q.ux / n * P.R, y: P.cy - q.uy / n * P.R};
            });
            if (!any) { return; }
            g.beginPath();
            pts.forEach((q, i) => { if (i) { g.lineTo(q.x, q.y); } else { g.moveTo(q.x, q.y); } });
            g.closePath(); g.fill(); g.stroke();
        });
        g.strokeStyle = 'rgba(160,200,255,.14)'; g.lineWidth = 1;
        for (let lon = -180; lon < 180; lon += 15) {
            const line = []; for (let lat = -90; lat <= 90; lat += 3) { line.push([lon, lat]); }
            path(g, P, line, 0);
        }
        for (let lat = -75; lat <= 75; lat += 15) {
            const line = []; for (let lon = -180; lon <= 180; lon += 3) { line.push([lon, lat]); }
            path(g, P, line, 0);
        }
        const shade = g.createRadialGradient(P.cx, P.cy, P.R * 0.55, P.cx, P.cy, P.R);   // darken towards the edge
        shade.addColorStop(0, 'rgba(0,0,0,0)'); shade.addColorStop(1, 'rgba(0,0,0,.55)');
        g.fillStyle = shade; g.fillRect(P.cx - P.R, P.cy - P.R, 2 * P.R, 2 * P.R);
        g.restore();
    }
    function circlePoints(km) {      // points on the ground at this distance from the observer
        const a = km / EARTH_KM, lat0 = sky.location.lat * RAD, lon0 = sky.location.lon * RAD, out = [];
        for (let b = 0; b <= 360; b += 4) {
            const lat = Math.asin(Math.sin(lat0) * Math.cos(a) + Math.cos(lat0) * Math.sin(a) * Math.cos(b * RAD));
            const lon = lon0 + Math.atan2(Math.sin(b * RAD) * Math.sin(a) * Math.cos(lat0), Math.cos(a) - Math.sin(lat0) * Math.sin(lat));
            out.push([lon / RAD, lat / RAD]);
        }
        return out;
    }
    function groundKm(lat, lon) {
        const a = sky.location.lat * RAD, b = lat * RAD, d = (lon - sky.location.lon) * RAD;
        return Math.acos(Math.max(-1, Math.min(1, Math.sin(a) * Math.sin(b) + Math.cos(a) * Math.cos(b) * Math.cos(d)))) * EARTH_KM;
    }
    const shellOf = sat => SHELLS.find(sh => sat.rec.inclo / RAD < sh.max) || SHELLS[SHELLS.length - 1];

    function updatePositions() {
        // every satellite every 5 seconds; the ones in view every second
        if (tick % 15 === 0) { sky.refresh(clock, minEl); }
        overhead = StarlinkSky.rank(sky.overhead(clock, minEl), boresight);
        const live = new Set(overhead.map(o => o.sat));
        if (selected) { live.add(selected); }
        if (tick % 5 === 0) { positions = sky.sats.map(s => ({sat: s, g: sky.ground(s, clock)})); }
        const area = +$('#sl-area').val();
        positions.forEach(function (p) {
            if (live.has(p.sat) || (p.g && p.near)) { p.g = sky.ground(p.sat, clock); }
            p.near = !!p.g && (live.has(p.sat) || (area > 0 && groundKm(p.g.lat, p.g.lon) <= area));
        });
        track = [];
        if (selected) {                       // where the selected satellite flies, 10 minutes either side of now
            for (let t = -600; t <= 600; t += 20) {
                const q = sky.ground(selected, new Date(clock.getTime() + t * 1000));
                if (q) { track.push([q.lon, q.lat, q.height]); }
            }
        }
        tick++;
    }

    function draw() {
        if (!sky || !view) { return; }
        const s = size(), g = StarlinkSky.setup(canvas, s.w, s.h), P = projector(s);
        const names = $('#sl-names').prop('checked');
        drawSpace(g, s, P); drawEarth(g, P);
        g.strokeStyle = 'rgba(120,200,255,.75)'; g.lineWidth = 1.5; g.setLineDash([6, 5]);
        path(g, P, circlePoints(StarlinkSky.footprintKm(minEl, 550)), 0);
        g.setLineDash([]);
        if (track.length) { g.strokeStyle = 'rgba(255,205,80,.9)'; g.lineWidth = 1.5; path(g, P, track); }

        const up = new Map(overhead.map((o, i) => [o.sat, i]));
        drawn = [];
        positions.forEach(function (p) {
            if (!p.near) { return; }
            const q = P(p.g.lat, p.g.lon, p.g.height);
            if (!q.visible || q.x < -20 || q.x > s.w + 20 || q.y < -20 || q.y > s.h + 20) { return; }
            drawn.push({x: q.x, y: q.y, sat: p.sat, at: p.g, rank: up.has(p.sat) ? up.get(p.sat) : null});
        });
        const me = P(sky.location.lat, sky.location.lon, 0);
        const nearest = boresight && drawn.find(d => d.rank === 0);
        // a drop line to the ground under each overhead satellite gives a sense of height
        drawn.filter(d => d.rank !== null).forEach(function (d) {
            const foot = P(d.at.lat, d.at.lon, 0);
            if (foot.z <= 0) { return; }
            g.strokeStyle = 'rgba(255,255,255,.28)'; g.lineWidth = 1;
            g.beginPath(); g.moveTo(foot.x, foot.y); g.lineTo(d.x, d.y); g.stroke();
        });
        if (nearest && me.z > 0) {
            g.strokeStyle = '#4dff88'; g.lineWidth = 2; g.setLineDash([5, 4]);
            g.beginPath(); g.moveTo(me.x, me.y); g.lineTo(nearest.x, nearest.y); g.stroke(); g.setLineDash([]);
        }
        drawn.forEach(function (d) {
            const isUp = d.rank !== null, near = boresight && d.rank === 0, color = near ? '#4dff88' : shellOf(d.sat).color;
            g.globalAlpha = isUp ? 1 : 0.6;
            g.fillStyle = color; g.beginPath(); g.arc(d.x, d.y, near ? 6 : (isUp ? 4 : 2.2), 0, Math.PI * 2); g.fill();
            if (isUp) { g.strokeStyle = color; g.lineWidth = 1; g.globalAlpha = 0.5; g.beginPath(); g.arc(d.x, d.y, near ? 11 : 8, 0, Math.PI * 2); g.stroke(); }
            g.globalAlpha = 1;
        });
        if (me.z > 0) {
            g.fillStyle = '#ff5a36'; g.strokeStyle = '#fff'; g.lineWidth = 2;
            g.beginPath(); g.arc(me.x, me.y, 6, 0, Math.PI * 2); g.fill(); g.stroke();
            g.font = 'bold 12px sans-serif'; g.fillStyle = '#fff'; g.fillText('You', me.x + 10, me.y + 14);
        }
        // names: selected first, then nearest to pointing, skipping any that would overlap
        const boxes = [];
        g.font = '11px sans-serif';
        drawn.filter(d => d.sat === selected || (names && view.name !== 'globe' && d.rank !== null))
            .sort((a, b) => (a.sat === selected ? -1 : b.sat === selected ? 1 : a.rank - b.rank))
            .forEach(function (d) {
                const lines = [d.sat.name, Math.round(d.at.height) + ' km'];
                const w = Math.max(...lines.map(t => g.measureText(t).width)), box = {x: d.x + 11, y: d.y - 13, w: w, h: 26};
                const hit = boxes.some(o => box.x < o.x + o.w && o.x < box.x + box.w && box.y < o.y + o.h && o.y < box.y + box.h);
                if (hit && d.sat !== selected) { return; }
                boxes.push(box);
                g.shadowColor = '#000'; g.shadowBlur = 4;
                g.fillStyle = d.sat === selected ? '#ffcd50' : '#fff'; g.fillText(lines[0], box.x, box.y + 11);
                g.fillStyle = 'rgba(255,255,255,.65)'; g.fillText(lines[1], box.x, box.y + 23);
                g.shadowBlur = 0;
            });
        const sel = selected && drawn.find(d => d.sat === selected);
        if (sel) { g.strokeStyle = '#ffcd50'; g.lineWidth = 2.5; g.beginPath(); g.arc(sel.x, sel.y, 13, 0, Math.PI * 2); g.stroke(); }
        drawLegend(g, s);
    }
    function drawLegend(g, s) {
        const rows = SHELLS.map(sh => [sh.color, sh.name]).concat(boresight ? [['#4dff88', 'Nearest to dish pointing']] : []);
        const w = 168, h = rows.length * 17 + 30, x = s.w - w - 10, y = s.h - h - 10;
        g.fillStyle = 'rgba(8,12,22,.82)'; g.fillRect(x, y, w, h);
        g.fillStyle = '#fff'; g.font = 'bold 11px sans-serif'; g.fillText(drawn.length + ' satellites shown', x + 10, y + 17);
        g.font = '11px sans-serif';
        rows.forEach(function (r, i) {
            const ry = y + 28 + i * 17;
            g.fillStyle = r[0]; g.fillRect(x + 10, ry, 10, 10);
            g.fillStyle = 'rgba(255,255,255,.85)'; g.fillText(r[1], x + 27, ry + 9);
        });
    }

    function panels() {
        const show = selected || (overhead[0] && overhead[0].sat);
        let rows = [];
        if (show) {
            const at = sky.ground(show, clock), l = sky.look(show, clock);
            if (at && l) {
                rows = [['Name', show.name], ['NORAD ID', show.rec.satnum], ['Orbit', (show.rec.inclo / RAD).toFixed(1) + DEG + ' inclination'],
                    ['Height', Math.round(at.height) + ' km'], ['Speed', at.speed ? at.speed.toFixed(2) + ' km/s' : '–'],
                    ['Over', at.lat.toFixed(1) + DEG + ', ' + at.lon.toFixed(1) + DEG],
                    ['Azimuth', l.az.toFixed(0) + DEG], ['Elevation', l.el.toFixed(0) + DEG + (l.el < minEl ? ' (not overhead)' : '')],
                    ['Distance', Math.round(l.range) + ' km']];
            }
        }
        $('#sl-detail').html(rows.map(r => '<dt>' + esc(r[0]) + '</dt><dd>' + esc(r[1]) + '</dd>').join('') || '<dt>–</dt><dd></dd>');
        $('#sl-over-title').text('Overhead: ' + overhead.length);
        $('#sl-over').html(overhead.slice(0, 12).map((o, i) =>
            '<div class="sl-pick' + (boresight && i === 0 ? ' sl-near' : '') + (o.sat === selected ? ' sl-sel' : '') + '" data-name="' + esc(o.name) + '">' +
            '<span>' + esc(o.name) + '</span><span>' + o.el.toFixed(0) + DEG + ' el · ' + Math.round(o.range) + ' km</span></div>').join(''));
        $('#sl-clock').text((paused ? 'Paused at ' : '') + clock.toLocaleTimeString());
    }

    function frame() {
        if (!sky || paused || document.hidden) { return; }
        clock = new Date();
        updatePositions(); draw(); panels();
    }
    function refreshNow() { tick = 0; updatePositions(); draw(); panels(); }

    // ---------------------------------------------------------- interaction
    $('.sl-view').click(function () { setView($(this).data('view')); draw(); });
    $('#sl-names').change(draw);
    $('#sl-area').change(refreshNow);
    $('#sl-pause').click(function () {
        paused = !paused;
        $(this).find('i').toggleClass('fa-pause', !paused).toggleClass('fa-play', paused);
        $(this).find('span').text(paused ? 'Resume' : 'Pause');
        if (paused) { panels(); } else { tick = 0; frame(); }
    });
    // delegated so the handler survives the list being redrawn every second
    $('#sl-over').on('mousedown', '.sl-pick', function () {
        const name = $(this).data('name');
        selected = (overhead.find(o => o.name === String(name)) || {}).sat || null;
        refreshNow();
    });
    let drag = null, pending = false;
    function redrawSoon() {
        if (pending) { return; }
        pending = true;
        window.requestAnimationFrame(function () { pending = false; draw(); });
    }
    $(canvas).on('pointerdown', function (e) {
        drag = {x: e.clientX, y: e.clientY, lat: view.lat, lon: view.lon, moved: false};
        canvas.setPointerCapture(e.originalEvent.pointerId);
        $(canvas).addClass('sl-drag');
    }).on('pointermove', function (e) {
        if (!drag) { return; }
        const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
        if (Math.hypot(dx, dy) > 3) { drag.moved = true; }
        if (!drag.moved) { return; }
        const s = size(), perPixel = 1 / (Math.min(s.w, s.h) * view.zoom) / RAD;
        view.lon = ((drag.lon - dx * perPixel + 540) % 360) - 180;
        view.lat = Math.max(-85, Math.min(85, drag.lat + dy * perPixel));
        redrawSoon();
    }).on('pointerup pointercancel', function (e) {
        if (drag && !drag.moved && e.type === 'pointerup') {
            const rect = canvas.getBoundingClientRect(), x = e.clientX - rect.left, y = e.clientY - rect.top;
            let best = null, dist = 14;
            drawn.forEach(function (d) { const r = Math.hypot(d.x - x, d.y - y); if (r < dist) { dist = r; best = d.sat; } });
            selected = best;
            refreshNow();
        }
        drag = null;
        $(canvas).removeClass('sl-drag');
    });
    canvas.addEventListener('wheel', function (e) {
        e.preventDefault();
        view.zoom = Math.max(0.3, Math.min(6, view.zoom * (e.deltaY < 0 ? 1.15 : 1 / 1.15)));
        redrawSoon();
    }, {passive: false});
    $(window).on('resize', redrawSoon);

    // ----------------------------------------------------------------- data
    function loadDish() {
        ajaxGet('/api/starlink/dish/status', {}, function (d) {
            const a = d && d.ok && d.alignment;
            boresight = a && a.azimuth_deg != null && a.elevation_deg != null ? {az: a.azimuth_deg, el: a.elevation_deg} : null;
        });
    }
    function loadData(first) {
        ajaxGet('/api/starlink/dish/satellites', {}, function (d) {
            if (!d || !d.ok) { if (first) { message((d && d.error) || 'No satellite data'); } return; }
            if (!d.enabled || !d.configured) {
                sky = null;
                message('Turn on satellite tracking and enter your location under Services: Starlink: Status, Settings tab.');
                return;
            }
            const name = selected && selected.name;
            data = d; sky = StarlinkSky.create(d);
            selected = sky.sats.find(s => s.name === name) || null;
            tick = 0;
            $('#sl-live-msg').hide(); $('#sl-live-body').show();
            if (first || !view) { setView('region'); }
            const hours = (Date.now() / 1000 - data.fetched) / 3600;
            $('#sl-live-age').text('Orbit data from CelesTrak (' + sky.sats.length + ' satellites), downloaded ' +
                (hours < 1 ? 'less than an hour' : Math.round(hours) + ' h') + ' ago. Map: Natural Earth.' + (data.warning ? ' ' + data.warning : ''));
            paused = false;
            frame();
        });
    }
    $.getJSON('/ui/js/starlink/countries-50m.json').done(function (topology) { world = StarlinkSky.parseWorld(topology); draw(); });
    ajaxGet('/api/starlink/dish/obstruction', {}, function (m) { if (m && m.ok && m.min_elevation_deg) { minEl = m.min_elevation_deg; tick = 0; } });
    loadDish();
    loadData(true);
    setInterval(frame, 1000);
    setInterval(function () { if (!document.hidden) { loadDish(); } }, 30000);
    setInterval(function () { if (!document.hidden && sky) { loadData(false); } }, 3 * 3600 * 1000);
});
</script>
