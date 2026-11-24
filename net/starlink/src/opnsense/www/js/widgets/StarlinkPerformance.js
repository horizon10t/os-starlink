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

/* Live latency / download / upload numbers with a 15 minute throughput sparkline. */
export default class StarlinkPerformance extends BaseWidget {
    constructor() {
        super();
        this.tickTimeout = 10;
        this.history = null;
        this.historyAt = 0;
    }

    getMarkup() {
        const t = this.translations;
        return $(`
            <div style="padding: 4px 6px">
                <div style="display:flex; gap:18px; flex-wrap:wrap; align-items:baseline">
                    <div><div style="font-size:11px; text-transform:uppercase; opacity:.65">${t.latency}</div>
                         <div style="font-size:24px; font-weight:600" id="starlink-perf-latency">&ndash;</div></div>
                    <div><div style="font-size:11px; text-transform:uppercase; opacity:.65">${t.download}</div>
                         <div style="font-size:24px; font-weight:600; color:#2f7ed8" id="starlink-perf-down">&ndash;</div></div>
                    <div><div style="font-size:11px; text-transform:uppercase; opacity:.65">${t.upload}</div>
                         <div style="font-size:24px; font-weight:600; color:#e4a32e" id="starlink-perf-up">&ndash;</div></div>
                </div>
                <canvas id="starlink-perf-chart" style="width:100%; height:90px; display:block; margin-top:8px"></canvas>
                <div class="text-muted" style="font-size:11px" id="starlink-perf-note"></div>
            </div>`);
    }

    draw() {
        const c = document.getElementById('starlink-perf-chart');
        if (!c || !this.history) { return; }
        const w = c.clientWidth, h = c.clientHeight, dpr = window.devicePixelRatio || 1;
        c.width = w * dpr;
        c.height = h * dpr;
        const g = c.getContext('2d');
        g.scale(dpr, dpr);
        g.clearRect(0, 0, w, h);
        const down = this.history.series.downlink_mbps, up = this.history.series.uplink_mbps;
        const n = Math.max(down.length, up.length);
        if (n < 2) { return; }
        const max = Math.max(1, ...down, ...up) * 1.1;
        const trace = (data) => {
            g.beginPath();
            data.forEach((v, i) => {
                const x = w * i / (n - 1), y = h - 2 - (h - 4) * Math.min(v, max) / max;
                if (i) { g.lineTo(x, y); } else { g.moveTo(x, y); }
            });
        };
        trace(down);
        g.lineTo(w * (down.length - 1) / (n - 1), h);
        g.lineTo(0, h);
        g.closePath();
        g.globalAlpha = 0.15;
        g.fillStyle = '#2f7ed8';
        g.fill();
        g.globalAlpha = 1;
        g.lineWidth = 1.5;
        trace(down);
        g.strokeStyle = '#2f7ed8';
        g.stroke();
        trace(up);
        g.strokeStyle = '#e4a32e';
        g.stroke();
    }

    async onWidgetTick() {
        const t = this.translations;
        const d = await this.ajaxCall('/api/starlink/dish/status');
        if (!d || !d.ok) {
            $('#starlink-perf-latency, #starlink-perf-down, #starlink-perf-up').html('&ndash;');
            $('#starlink-perf-note').text(t.unreachable);
            return;
        }
        $('#starlink-perf-latency').text(`${d.latency_ms} ms`);
        $('#starlink-perf-down').text(`${d.downlink_mbps} Mbps`);
        $('#starlink-perf-up').text(`${d.uplink_mbps} Mbps`);
        $('#starlink-perf-note').text(`${(d.drop_rate * 100).toFixed(2)}% ${t.loss} · ${t.last15}`);
        // the history call is heavier, so refresh the chart only once a minute
        if (Date.now() - this.historyAt > 60000) {
            const hist = await this.ajaxCall('/api/starlink/dish/history?seconds=900');
            if (hist && hist.ok) {
                this.history = hist;
                this.historyAt = Date.now();
            }
        }
        this.draw();
    }

    onWidgetResize(elem, width, height) {
        this.draw();
        return super.onWidgetResize(elem, width, height);
    }
}
