<?php

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

namespace OPNsense\Starlink\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

/**
 * Thin wrapper around the configd "starlink" actions (dish.py).
 * Read actions are GET, anything that changes the dish requires POST.
 */
class DishController extends ApiControllerBase
{
    private function run($action, $params = [])
    {
        $out = trim((new Backend())->configdpRun('starlink ' . $action, $params));
        $data = json_decode($out, true);
        if (!is_array($data)) {
            return ['ok' => false, 'error' => 'invalid response from backend', 'raw' => substr($out, 0, 500)];
        }
        return $data;
    }

    private function requirePost()
    {
        return $this->request->isPost() ? null : ['ok' => false, 'error' => 'must be called via POST'];
    }

    private static function validTime($value)
    {
        return is_string($value) && preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $value) === 1;
    }

    public function statusAction()
    {
        return $this->run('status');
    }

    public function historyAction()
    {
        $seconds = (int)$this->request->get('seconds', null, 900);
        $seconds = max(60, min(43200, $seconds));
        return $this->run('history', [(string)$seconds]);
    }

    public function obstructionAction()
    {
        return $this->run('obstruction');
    }

    public function infoAction()
    {
        return $this->run('info');
    }

    public function sleepAction()
    {
        if (($err = $this->requirePost()) !== null) {
            return $err;
        }
        $mode = $this->request->getPost('mode');
        if ($mode === 'off') {
            return $this->run('sleep', ['off', '', '']);
        }
        if ($mode === 'set') {
            $start = $this->request->getPost('start');
            $end = $this->request->getPost('end');
            if (!self::validTime($start) || !self::validTime($end)) {
                return ['ok' => false, 'error' => 'times must be HH:MM (24-hour)'];
            }
            return $this->run('sleep', ['set', $start, $end]);
        }
        return ['ok' => false, 'error' => 'mode must be "set" or "off"'];
    }

    public function wakeAction()
    {
        if (($err = $this->requirePost()) !== null) {
            return $err;
        }
        $hours = $this->request->getPost('hours', null, '0');
        if (!is_numeric($hours) || $hours < 0 || $hours > 168) {
            return ['ok' => false, 'error' => 'hours must be between 0 and 168'];
        }
        return $this->run('wake', [(string)(0 + $hours)]);
    }

    public function resumeAction()
    {
        return $this->requirePost() ?? $this->run('resume');
    }

    public function resyncAction()
    {
        return $this->requirePost() ?? $this->run('resync');
    }

    public function rebootAction()
    {
        return $this->requirePost() ?? $this->run('reboot');
    }

    /* Plugin self-update: the check only contacts GitHub when called, the update needs POST. */
    public function pluginCheckAction()
    {
        return $this->run('plugin-check');
    }

    public function pluginUpdateAction()
    {
        return $this->requirePost() ?? $this->run('plugin-update');
    }

    public function stowAction()
    {
        return $this->requirePost() ?? $this->run('stow');
    }

    public function unstowAction()
    {
        return $this->requirePost() ?? $this->run('unstow');
    }

    public function gpsAction()
    {
        if (($err = $this->requirePost()) !== null) {
            return $err;
        }
        $state = $this->request->getPost('state');
        if (!in_array($state, ['on', 'off'], true)) {
            return ['ok' => false, 'error' => 'state must be on or off'];
        }
        return $this->run('gps', [$state]);
    }

    public function snowmeltAction()
    {
        if (($err = $this->requirePost()) !== null) {
            return $err;
        }
        $mode = $this->request->getPost('mode');
        if (!in_array($mode, ['auto', 'on', 'off'], true)) {
            return ['ok' => false, 'error' => 'mode must be auto, on or off'];
        }
        return $this->run('snowmelt', [$mode]);
    }
}
