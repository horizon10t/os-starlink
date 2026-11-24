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

/* Hardware, software, GPS and pointing details of the dish. */
export default class StarlinkDish extends BaseTableWidget {
    constructor() {
        super();
        this.tickTimeout = 30;
    }

    getMarkup() {
        return $(this.createTable('starlink-dish-table', {headerPosition: 'left'}));
    }

    async onWidgetTick() {
        const t = this.translations;
        const d = await this.ajaxCall('/api/starlink/dish/status');
        if (!d || !d.ok) {
            super.updateTable('starlink-dish-table', [[t.state, `<span class="text-danger">${t.unreachable}</span>`]]);
            return;
        }
        const days = Math.floor(d.uptime_s / 86400), hours = Math.floor(d.uptime_s % 86400 / 3600);
        const gps = d.gps.inhibited ? t.disabled : (d.gps.valid ? `${d.gps.sats} ${t.sats}` : t.nofix);
        const rows = [
            [t.model, d.model ? d.model.name : (d.device.hardware_version || '–')],
            [t.software, d.device.software_version || '–'],
            [t.update, d.software_update_state || '–'],
            [t.uptime, `${days}d ${hours}h`],
            [t.gps, gps],
            [t.pointing, `${d.azimuth_deg ?? '–'}° / ${d.elevation_deg ?? '–'}°`],
        ];
        const a = d.alignment || {};
        if (a.quality) {
            const color = {good: 'success', fair: 'warning', poor: 'danger'}[a.quality];
            rows.push([t.alignment, `<span class="text-${color}"><b>${t[a.quality]}</b></span> (${a.azimuth_error_deg}° / ${a.elevation_error_deg}°)`]);
        }
        if (d.eth_speed_mbps) {
            rows.push([t.ethernet, `${d.eth_speed_mbps} Mbps`]);
        }
        super.updateTable('starlink-dish-table', rows);
    }
}
