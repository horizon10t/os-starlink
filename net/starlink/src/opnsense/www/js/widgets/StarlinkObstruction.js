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

/* Small sky map of what the dish sees, plus the obstructed percentage. */
export default class StarlinkObstruction extends BaseWidget {
    constructor() {
        super();
        this.tickTimeout = 120;
    }

    getMarkup() {
        const t = this.translations;
        return $(`
            <div style="display:flex; gap:14px; align-items:center; padding:4px 6px; flex-wrap:wrap">
                <canvas id="starlink-obs-map" width="123" height="123"
                    style="width:120px; height:120px; image-rendering:pixelated; border-radius:50%; border:1px solid rgba(128,128,128,.3)"></canvas>
                <div>
                    <div style="font-size:11px; text-transform:uppercase; opacity:.65">${t.obstructed}</div>
                    <div style="font-size:24px; font-weight:600" id="starlink-obs-pct">&ndash;</div>
                    <div class="text-muted" style="font-size:12px" id="starlink-obs-sub"></div>
                    <a href="/ui/starlink#tab-obstruction" style="font-size:12px">${t.details}</a>
                </div>
            </div>`);
    }

    async onWidgetTick() {
        const t = this.translations;
        const [m, s] = await Promise.all([
            this.ajaxCall('/api/starlink/dish/obstruction'),
            this.ajaxCall('/api/starlink/dish/status'),
        ]);
        if (s && s.ok) {
            const pct = s.obstruction.fraction_obstructed * 100;
            $('#starlink-obs-pct').text(`${pct.toFixed(2)}%`)
                .css('color', pct < 1 ? '#3c9a3c' : (pct < 5 ? '#e0a030' : '#c9302c'));
            $('#starlink-obs-sub').text(s.obstruction.currently_obstructed ? t.now : t.clear);
        } else {
            $('#starlink-obs-pct').html('&ndash;');
            $('#starlink-obs-sub').text(t.unreachable);
        }
        const c = document.getElementById('starlink-obs-map');
        if (!c || !m || !m.ok || !m.cols) { return; }
        c.width = m.cols;
        c.height = m.rows;
        const g = c.getContext('2d');
        const img = g.createImageData(m.cols, m.rows);
        m.snr.forEach((v, i) => {
            const p = i * 4;
            if (v < 0) {
                img.data[p + 3] = 0;
                return;
            }
            img.data[p] = Math.round(255 * (1 - v));
            img.data[p + 1] = Math.round(200 * v);
            img.data[p + 2] = 40;
            img.data[p + 3] = 255;
        });
        g.putImageData(img, 0, 0);
    }
}
