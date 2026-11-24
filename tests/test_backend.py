#!/usr/bin/env python3
"""Unit tests for the stdlib-only dish client and backend helpers (no dish needed)."""

import os
import struct
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'net', 'starlink', 'src', 'opnsense', 'scripts', 'starlink'))

import starlink_client as sc  # noqa: E402
import dish  # noqa: E402


class Protobuf(unittest.TestCase):
    def test_request_encoding(self):
        # dish_power_save = 2013 -> tag (2013 << 3 | 2) = 16106 -> varint ea 7d
        raw = sc.encode('Request', {'dish_power_save': {
            'power_save_start_minutes': 630, 'power_save_duration_minutes': 345, 'enable_power_save': True}})
        self.assertEqual(raw[:2], bytes([0xea, 0x7d]))
        self.assertEqual(raw[3:], bytes([0x08, 0xf6, 0x04, 0x10, 0xd9, 0x02, 0x18, 0x01]))

    def test_roundtrip_nested_and_enum(self):
        req = {'dish_set_config': {'dish_config': {'snow_melt_mode': 'ALWAYS_OFF', 'apply_snow_melt_mode': True}}}
        self.assertEqual(sc.decode('Request', sc.encode('Request', req)), req)

    def test_packed_floats_and_unknown_fields(self):
        floats = [1.5, 2.5, 3.5]
        packed = struct.pack('<3f', *floats)
        body = bytes([0x08, 0x05])  # current = 5
        body += sc._enc_varint(1002 << 3 | 2) + sc._enc_varint(len(packed)) + packed  # pop_ping_latency_ms
        body += sc._enc_varint(99999 << 3 | 0) + b'\x01'  # unknown field, must be skipped
        out = sc.decode('DishGetHistoryResponse', body)
        self.assertEqual(out['current'], 5)
        self.assertEqual(out['pop_ping_latency_ms'], floats)

    def test_negative_int32(self):
        self.assertEqual(sc.decode('Status.Status', sc.encode('Status.Status', {'code': -3}))['code'], -3)


class Hpack(unittest.TestCase):
    def test_rfc7541_c41_huffman(self):
        block = bytes.fromhex('828684418cf1e3c2e5f23a6ba0ab90f4ff')
        self.assertEqual(sc.HpackDecoder().decode(block), [
            (':method', 'GET'), (':scheme', 'http'), (':path', '/'), (':authority', 'www.example.com')])

    def test_rfc7541_c42_dynamic_table(self):
        dec = sc.HpackDecoder()
        dec.decode(bytes.fromhex('828684418cf1e3c2e5f23a6ba0ab90f4ff'))
        self.assertEqual(dec.decode(bytes.fromhex('828684be5886a8eb10649cbf')), [
            (':method', 'GET'), (':scheme', 'http'), (':path', '/'), (':authority', 'www.example.com'),
            ('cache-control', 'no-cache')])

    def test_encoder_roundtrip(self):
        hdrs = [(':method', 'POST'), (':path', '/SpaceX.API.Device.Device/Handle'), ('te', 'trailers')]
        self.assertEqual(sc.HpackDecoder().decode(sc.hpack_encode(hdrs)), hdrs)


class Helpers(unittest.TestCase):
    def test_ring_buffer_order(self):
        self.assertEqual(dish._ordered([6, 7, 3, 4, 5], 7, 5), [3, 4, 5, 6, 7])
        self.assertEqual(dish._ordered([1, 2, 3, 0, 0], 3, 10), [1, 2, 3])

    def test_local_window(self):
        os.environ['TZ'] = 'UTC'
        if hasattr(__import__('time'), 'tzset'):
            __import__('time').tzset()
        self.assertEqual(dish.local_window_to_utc('23:30', '05:15'), (1410, 345))
        self.assertEqual(dish.local_window_to_utc('01:00', '06:00'), (60, 300))
        with self.assertRaises(sc.DishError):
            dish.local_window_to_utc('01:00', '01:00')
        with self.assertRaises(sc.DishError):
            dish.local_window_to_utc('24:00', '01:00')


class Models(unittest.TestCase):
    def test_auto_detects_from_hardware_version(self):
        m = dish.resolve_model({'model': 'auto'}, 'rev4_prod2')
        self.assertEqual((m['key'], m['detected']), ('gen3', 'gen3'))
        self.assertNotIn('stow', m['features'])
        self.assertEqual(dish.resolve_model({'model': 'auto'}, 'mini1_prod2')['key'], 'mini')

    def test_unknown_hardware_shows_everything(self):
        m = dish.resolve_model({'model': 'auto'}, 'something_new')
        self.assertEqual(m['key'], 'all')
        self.assertEqual(set(m['features']), set(dish.FEATURES))

    def test_dish_actuator_flag_overrides_in_auto_mode(self):
        self.assertIn('stow', dish.resolve_model({'model': 'auto'}, 'rev4_prod2', 'HAS_ACTUATORS_YES')['features'])
        self.assertNotIn('stow', dish.resolve_model({'model': 'auto'}, 'rev2_proto3', 'HAS_ACTUATORS_NO')['features'])

    def test_manual_choice_wins_and_bad_value_falls_back(self):
        self.assertEqual(dish.resolve_model({'model': 'mini'}, 'rev2_proto3')['key'], 'mini')
        self.assertEqual(dish.resolve_model({'model': 'bogus'}, None)['key'], 'all')

    def test_every_command_feature_exists(self):
        for feature in dish.COMMAND_FEATURE.values():
            self.assertIn(feature, dish.FEATURES)


class Alignment(unittest.TestCase):
    def _st(self, az, el, d_az, d_el):
        return {'alignment_stats': {'boresight_azimuth_deg': az, 'boresight_elevation_deg': el,
                                    'desired_boresight_azimuth_deg': d_az, 'desired_boresight_elevation_deg': d_el}}

    def test_azimuth_error_wraps_around_north(self):
        a = dish.alignment_info(self._st(359.0, 70.0, 1.0, 70.0))
        self.assertEqual(a['azimuth_error_deg'], -2.0)
        self.assertEqual(a['quality'], 'good')

    def test_negative_azimuth_is_shown_as_compass_bearing(self):
        a = dish.alignment_info(self._st(-173.9, 68.7, 180.0, 65.1))
        self.assertEqual(a['azimuth_deg'], 186.1)
        self.assertEqual(a['desired_azimuth_deg'], 180.0)
        self.assertEqual(a['azimuth_error_deg'], 6.1)   # unchanged by the display fix: still wraps correctly
        self.assertEqual(a['quality'], 'poor')

    def test_quality_bands(self):
        self.assertEqual(dish.alignment_info(self._st(100, 60, 100, 63))['quality'], 'fair')
        self.assertEqual(dish.alignment_info(self._st(100, 60, 110, 60))['quality'], 'poor')

    def test_unreported_target_gives_no_quality(self):
        self.assertIsNone(dish.alignment_info(self._st(100, 60, None, None))['quality'])
        self.assertIsNone(dish.alignment_info(self._st(100, 60, 0, 0))['quality'])   # zero = unset default
        self.assertIsNone(dish.alignment_info({})['azimuth_deg'])


class Updates(unittest.TestCase):
    def test_version_compare(self):
        self.assertGreater(dish.parse_version('1.0'), dish.parse_version('0.9'))
        self.assertGreater(dish.parse_version('0.10'), dish.parse_version('0.9'))
        self.assertEqual(dish.parse_version('v1.2.3\n'), (1, 2, 3))
        with self.assertRaises(sc.DishError):
            dish.parse_version('not a version')

    def test_dish_update_states(self):
        self.assertTrue(dish.update_info({'software_update_state': 'REBOOT_REQUIRED'})['ready'])
        self.assertTrue(dish.update_info({'swupdate_reboot_ready': True})['ready'])
        busy = dish.update_info({'software_update_state': 'WRITING',
                                 'software_update_stats': {'software_update_progress': 0.4}})
        self.assertTrue(busy['in_progress'])
        self.assertFalse(busy['ready'])
        self.assertEqual(busy['progress'], 0.4)
        idle = dish.update_info({'software_update_state': 'IDLE'})
        self.assertFalse(idle['ready'] or idle['in_progress'])

    def test_plugin_check_flags_newer_version(self):
        orig = (dish.installed_version, dish.latest_version, dish.pkg_managed)
        try:
            dish.installed_version = lambda: '0.9'
            dish.latest_version = lambda: '0.10'
            dish.pkg_managed = lambda: False
            out = dish.cmd_plugin_check({}, None, [])
            self.assertTrue(out['available'])
            dish.latest_version = lambda: '0.9'
            self.assertFalse(dish.cmd_plugin_check({}, None, [])['available'])
        finally:
            dish.installed_version, dish.latest_version, dish.pkg_managed = orig

    def test_package_install_is_not_self_updated(self):
        orig = dish.pkg_managed
        try:
            dish.pkg_managed = lambda: True
            with self.assertRaises(sc.DishError):
                dish.cmd_plugin_update({}, None, [])
        finally:
            dish.pkg_managed = orig


if __name__ == '__main__':
    unittest.main(verbosity=1)
