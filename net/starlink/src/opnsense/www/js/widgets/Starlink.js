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

export default class Starlink extends BaseTableWidget {
    constructor() {
        super();
        this.tickTimeout = 15;
    }

    getMarkup() {
        const $container = $('<div></div>');
        $container.append(this.createTable('starlink-table', {headerPosition: 'left'}));
        $container.append($(`
            <div style="padding: 6px 0 2px">
                <button class="btn btn-primary btn-xs" id="starlink-wake"><i class="fa fa-sun-o fa-sun fa-fw"></i> ${this.translations.wake}</button>
                <button class="btn btn-default btn-xs" id="starlink-resume" style="display:none">${this.translations.resume}</button>
                <a href="/ui/starlink" class="btn btn-default btn-xs"><i class="fa fa-external-link fa-fw"></i></a>
            </div>`));
        return $container;
    }

    async onMarkupRendered() {
        $('#starlink-wake').on('click', async (e) => {
            e.preventDefault();
            await this.ajaxCall('/api/starlink/dish/wake', JSON.stringify({hours: 2}), 'POST');
            await this.onWidgetTick();
        });
        $('#starlink-resume').on('click', async (e) => {
            e.preventDefault();
            await this.ajaxCall('/api/starlink/dish/resume', JSON.stringify({}), 'POST');
            await this.onWidgetTick();
        });
    }

    async onWidgetTick() {
        const t = this.translations;
        const d = await this.ajaxCall('/api/starlink/dish/status');
        if (!d || !d.ok) {
            super.updateTable('starlink-table', [[t.state, `<span class="text-danger">${t.unreachable}</span>`]]);
            return;
        }
        const color = d.state === 'CONNECTED' ? 'success' : (d.state === 'SLEEPING' ? 'info' : 'danger');
        const sleep = d.sleep && d.sleep.enabled ? `${d.sleep.start_local} \u2013 ${d.sleep.end_local}` : t.disabled;
        const hold = d.wake_hold ? (d.wake_hold.indefinite ? ' (paused)' : ` (awake until ${d.wake_hold.until_local.slice(11)})`) : '';
        const alerts = d.alerts.filter(a => a !== 'is_heating').map(a => a.replace(/_/g, ' '));
        super.updateTable('starlink-table', [
            [t.state, `<span class="text-${color}"><b>${d.state.replace(/_/g, ' ')}</b></span>`],
            [t.latency, `${d.latency_ms} ms (${(d.drop_rate * 100).toFixed(1)}% drop)`],
            [t.throughput, `${d.downlink_mbps} / ${d.uplink_mbps} Mbps`],
            [t.obstructed, `${(d.obstruction.fraction_obstructed * 100).toFixed(2)}%`],
            [t.sleep, sleep + hold],
            [t.alerts, alerts.length ? alerts.join(', ') : t.none],
        ]);
        $('#starlink-resume').toggle(!!d.wake_hold);
    }
}
