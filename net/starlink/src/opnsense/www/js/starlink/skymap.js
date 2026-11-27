/*
 * Copyright (C) 2026 os-starlink contributors
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Shared satellite maths and drawing for the status page card and the live map.
 * Positions are calculated here in the browser with satellite.js (SGP4) from public orbit data.
 */
window.StarlinkSky = (function () {
    const RAD = Math.PI / 180;
    const EARTH_KM = 6371;

    function create(data) {
        const observer = {latitude: data.location.lat * RAD, longitude: data.location.lon * RAD, height: 0};
        const sats = [];
        data.satellites.forEach(function (row) {
            try {
                const rec = satellite.twoline2satrec(row[1], row[2]);
                if (!rec.error) { sats.push({name: row[0], rec: rec}); }
            } catch (e) { /* skip a malformed element set */ }
        });
        let candidates = [];

        function propagate(s, date) {
            const pv = satellite.propagate(s.rec, date);
            if (!pv || !pv.position || !isFinite(pv.position.x)) { return null; }
            return pv;
        }
        // where to look from the observer: azimuth / elevation in degrees, range in km
        function look(s, date, gmst) {
            const pv = propagate(s, date);
            if (!pv) { return null; }
            const ecf = satellite.eciToEcf(pv.position, gmst === undefined ? satellite.gstime(date) : gmst);
            const a = satellite.ecfToLookAngles(observer, ecf);
            return {az: ((a.azimuth / RAD) + 360) % 360, el: a.elevation / RAD, range: a.rangeSat};
        }
        // the point on the ground below the satellite, its height (km) and speed (km/s)
        function ground(s, date, gmst) {
            const pv = propagate(s, date);
            if (!pv) { return null; }
            const g = satellite.eciToGeodetic(pv.position, gmst === undefined ? satellite.gstime(date) : gmst);
            const v = pv.velocity;
            return {lat: g.latitude / RAD, lon: ((g.longitude / RAD + 540) % 360) - 180, height: g.height,
                speed: v ? Math.hypot(v.x, v.y, v.z) : null};
        }
        // full scan: remember the satellites that are above, or about to rise above, the minimum elevation
        function refresh(date, minEl) {
            const gmst = satellite.gstime(date);
            candidates = sats.filter(function (s) {
                const l = look(s, date, gmst);
                return l && l.el > minEl - 10;
            });
        }
        // satellites above minEl now, from the remembered candidates (cheap enough for every second)
        function overhead(date, minEl) {
            const gmst = satellite.gstime(date), out = [];
            candidates.forEach(function (s) {
                const l = look(s, date, gmst);
                if (l && l.el >= minEl) { out.push({sat: s, name: s.name, az: l.az, el: l.el, range: l.range}); }
            });
            return out;
        }
        return {location: data.location, sats: sats, look: look, ground: ground, refresh: refresh, overhead: overhead};
    }

    // angle in degrees between two directions in the sky
    function separation(az1, el1, az2, el2) {
        const c = Math.sin(el1 * RAD) * Math.sin(el2 * RAD) +
            Math.cos(el1 * RAD) * Math.cos(el2 * RAD) * Math.cos((az1 - az2) * RAD);
        return Math.acos(Math.max(-1, Math.min(1, c))) / RAD;
    }
    // sort by closeness to where the dish points; the first one is only "nearest", not "connected"
    function rank(list, boresight) {
        list.forEach(function (o) {
            o.off = boresight ? separation(o.az, o.el, boresight.az, boresight.el) : null;
        });
        return list.sort(function (a, b) { return boresight ? a.off - b.off : b.el - a.el; });
    }
    // ground distance (km) at which a satellite at this height is still above minEl
    function footprintKm(minEl, heightKm) {
        const psi = Math.acos(EARTH_KM / (EARTH_KM + heightKm) * Math.cos(minEl * RAD)) - minEl * RAD;
        return psi * EARTH_KM;
    }

    function setup(canvas, w, h) {
        const dpr = window.devicePixelRatio || 1;
        canvas.style.height = h + 'px';
        canvas.width = w * dpr;
        canvas.height = h * dpr;
        const g = canvas.getContext('2d');
        g.setTransform(dpr, 0, 0, dpr, 0, 0);
        g.clearRect(0, 0, w, h);
        return g;
    }

    // polar sky plot: centre = straight up, north at the top, edge = thetaMax degrees from straight up
    function drawSky(canvas, opts) {
        const size = opts.size, g = setup(canvas, size, size);
        canvas.style.width = size + 'px';
        const fg = getComputedStyle(document.body).color || '#555';
        const c = size / 2, R = size / 2 - 20, thetaMax = opts.thetaMax;
        const at = function (az, el) {
            const r = (90 - el) / thetaMax * R;
            return {x: c + r * Math.sin(az * RAD), y: c - r * Math.cos(az * RAD)};
        };
        g.save();
        g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.clip();
        g.fillStyle = 'rgba(128,128,128,.08)'; g.fillRect(0, 0, size, size);
        const m = opts.obstruction;
        if (m && m.frame === 'FRAME_EARTH' && m.cols) {
            const off = document.createElement('canvas');
            off.width = m.cols; off.height = m.rows;
            const og = off.getContext('2d'), img = og.createImageData(m.cols, m.rows);
            m.snr.forEach(function (v, i) {
                if (v < 0) { return; }
                img.data[i * 4] = Math.round(255 * (1 - v));
                img.data[i * 4 + 1] = Math.round(200 * v);
                img.data[i * 4 + 2] = 40;
                img.data[i * 4 + 3] = 255;
            });
            og.putImageData(img, 0, 0);
            g.globalAlpha = 0.28; g.imageSmoothingEnabled = false;
            g.drawImage(off, c - R, c - R, 2 * R, 2 * R);
            g.globalAlpha = 1;
        }
        g.restore();
        g.strokeStyle = 'rgba(128,128,128,.55)'; g.lineWidth = 1; g.fillStyle = fg; g.font = '10px sans-serif';
        [60, 30].forEach(function (el) {
            if (90 - el >= thetaMax) { return; }
            const r = (90 - el) / thetaMax * R;
            g.setLineDash([3, 4]); g.beginPath(); g.arc(c, c, r, 0, Math.PI * 2); g.stroke(); g.setLineDash([]);
            g.fillText(el + '°', c + 3, c - r - 2);
        });
        g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.stroke();
        g.font = 'bold 12px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
        g.fillText('N', c, c - R - 10); g.fillText('S', c, c + R + 10);
        g.fillText('E', c + R + 10, c); g.fillText('W', c - R - 10, c);
        g.textAlign = 'start'; g.textBaseline = 'alphabetic';
        const bore = opts.boresight ? at(opts.boresight.az, opts.boresight.el) : null;
        if (bore) {
            g.strokeStyle = '#2f7ed8'; g.lineWidth = 2;
            g.beginPath(); g.arc(bore.x, bore.y, 11, 0, Math.PI * 2); g.stroke();
        }
        g.font = '10px sans-serif';
        opts.list.forEach(function (o, i) {
            const p = at(o.az, o.el), first = bore && i === 0;
            if (first) {
                g.strokeStyle = '#3c9a3c'; g.lineWidth = 1.5; g.setLineDash([4, 4]);
                g.beginPath(); g.moveTo(bore.x, bore.y); g.lineTo(p.x, p.y); g.stroke(); g.setLineDash([]);
            }
            g.fillStyle = first ? '#3c9a3c' : fg;
            g.beginPath(); g.arc(p.x, p.y, first ? 5 : 3, 0, Math.PI * 2); g.fill();
            if (i < 4) { g.fillText(o.name.replace('STARLINK-', ''), p.x + 7, p.y + 3); }
        });
    }

    // TopoJSON (world-atlas) -> list of rings, each a list of [lon, lat]
    function parseWorld(topology) {
        const t = topology.transform;
        const arcs = topology.arcs.map(function (arc) {
            let x = 0, y = 0;
            return arc.map(function (d) {
                x += d[0]; y += d[1];
                return t ? [x * t.scale[0] + t.translate[0], y * t.scale[1] + t.translate[1]] : [d[0], d[1]];
            });
        });
        const rings = [];
        const ring = function (indexes) {
            const points = [];
            indexes.forEach(function (i) {
                const arc = i < 0 ? arcs[~i].slice().reverse() : arcs[i];
                for (let k = points.length ? 1 : 0; k < arc.length; k++) { points.push(arc[k]); }
            });
            // make the longitudes continuous so shapes crossing 180 degrees draw without streaks
            const out = [];
            let lon = 0, previous = 0, min = Infinity, max = -Infinity;
            points.forEach(function (p, n) {
                lon = n ? lon + ((p[0] - previous + 540) % 360) - 180 : p[0];
                previous = p[0];
                min = Math.min(min, lon); max = Math.max(max, lon);
                out.push([lon, p[1]]);
            });
            if (out.length > 2) { rings.push({points: out, min: min, max: max}); }
        };
        topology.objects.countries.geometries.forEach(function (geo) {
            if (geo.type === 'Polygon') { geo.arcs.forEach(ring); }
            if (geo.type === 'MultiPolygon') { geo.arcs.forEach(function (p) { p.forEach(ring); }); }
        });
        return rings;
    }

    return {create: create, separation: separation, rank: rank, footprintKm: footprintKm,
        setup: setup, drawSky: drawSky, parseWorld: parseWorld};
})();
