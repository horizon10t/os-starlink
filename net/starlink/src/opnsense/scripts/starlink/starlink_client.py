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

"""
Dependency-free client for the Starlink dish local API.

Speaks gRPC to SpaceX.API.Device.Device/Handle using only the Python
standard library:

  * protobuf encoding/decoding driven by the schema in starlink_proto.py
  * gRPC over cleartext HTTP/2 (h2c, port 9200) with a minimal HTTP/2 + HPACK
    implementation
  * gRPC-Web over HTTP/1.1 (port 9201) as a fallback transport
"""

import socket
import struct
import http.client

from starlink_proto import MESSAGES, ENUMS, HPACK_STATIC, HUFFMAN_CODES, HUFFMAN_LENGTHS

GRPC_PATH = '/SpaceX.API.Device.Device/Handle'


class DishError(Exception):
    pass


# --------------------------------------------------------------------------
# protobuf codec
# --------------------------------------------------------------------------

def _enc_varint(value):
    if value < 0:
        value += 1 << 64
    out = bytearray()
    while True:
        b = value & 0x7F
        value >>= 7
        if value:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _dec_varint(buf, pos):
    result = shift = 0
    while True:
        if pos >= len(buf):
            raise DishError('truncated varint')
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, pos
        shift += 7
        if shift > 70:
            raise DishError('varint too long')


def _field_index(msg_name):
    """name -> (number, spec) for a message."""
    return {spec[0]: (num, spec) for num, spec in MESSAGES[msg_name].items()}


def encode(msg_name, values):
    """Encode a dict into protobuf bytes using the schema."""
    index = _field_index(msg_name)
    out = bytearray()
    for key, val in values.items():
        if key not in index:
            raise DishError('unknown field %s.%s' % (msg_name, key))
        num, (_name, kind, repeated, ref) = index[key]
        items = val if repeated else [val]
        for item in items:
            if kind == 'msg':
                payload = encode(ref, item or {})
                out += _enc_varint(num << 3 | 2) + _enc_varint(len(payload)) + payload
            elif kind in ('string', 'bytes'):
                data = item.encode() if isinstance(item, str) else bytes(item)
                out += _enc_varint(num << 3 | 2) + _enc_varint(len(data)) + data
            elif kind == 'float':
                out += _enc_varint(num << 3 | 5) + struct.pack('<f', item)
            elif kind == 'double':
                out += _enc_varint(num << 3 | 1) + struct.pack('<d', item)
            elif kind in ('fixed32', 'sfixed32'):
                out += _enc_varint(num << 3 | 5) + struct.pack('<I' if kind == 'fixed32' else '<i', item)
            elif kind in ('fixed64', 'sfixed64'):
                out += _enc_varint(num << 3 | 1) + struct.pack('<Q' if kind == 'fixed64' else '<q', item)
            elif kind == 'enum' and isinstance(item, str):
                rev = {v: k for k, v in ENUMS[ref].items()}
                out += _enc_varint(num << 3) + _enc_varint(rev[item])
            elif kind in ('sint32', 'sint64'):
                zz = (item << 1) ^ (item >> 63)
                out += _enc_varint(num << 3) + _enc_varint(zz)
            else:  # int32/int64/uint32/uint64/bool/enum
                out += _enc_varint(num << 3) + _enc_varint(int(item))
    return bytes(out)


def _scalar_from_varint(kind, v, ref):
    if kind == 'bool':
        return bool(v)
    if kind in ('int32', 'int64'):
        return v - (1 << 64) if v >= 1 << 63 else v
    if kind in ('sint32', 'sint64'):
        return (v >> 1) ^ -(v & 1)
    if kind == 'enum':
        return ENUMS.get(ref, {}).get(v, v)
    return v


_PACKABLE = {
    'float': ('<f', 4), 'double': ('<d', 8), 'fixed32': ('<I', 4), 'sfixed32': ('<i', 4),
    'fixed64': ('<Q', 8), 'sfixed64': ('<q', 8),
}


def decode(msg_name, buf):
    """Decode protobuf bytes into a dict. Unknown fields are skipped."""
    schema = MESSAGES.get(msg_name, {})
    result = {}
    pos, end = 0, len(buf)
    while pos < end:
        tag, pos = _dec_varint(buf, pos)
        num, wire = tag >> 3, tag & 7
        if wire == 0:
            raw, pos = _dec_varint(buf, pos)
            data = None
        elif wire == 1:
            data = buf[pos:pos + 8]
            pos += 8
        elif wire == 5:
            data = buf[pos:pos + 4]
            pos += 4
        elif wire == 2:
            length, pos = _dec_varint(buf, pos)
            data = buf[pos:pos + length]
            pos += length
        else:
            raise DishError('unsupported wire type %d' % wire)
        if num not in schema:
            continue
        name, kind, repeated, ref = schema[num]
        values = []
        if wire == 0:
            values.append(_scalar_from_varint(kind, raw, ref))
        elif wire in (1, 5):
            fmt = _PACKABLE.get(kind, ('<Q', 8) if wire == 1 else ('<I', 4))[0]
            values.append(struct.unpack(fmt, data)[0])
        else:  # length delimited
            if kind == 'msg':
                values.append(decode(ref, data))
            elif kind == 'string':
                values.append(data.decode('utf-8', 'replace'))
            elif kind == 'bytes':
                values.append(data.hex())
            elif kind in _PACKABLE:
                fmt, size = _PACKABLE[kind]
                values.extend(x[0] for x in struct.iter_unpack(fmt, data[:len(data) - len(data) % size]))
            else:  # packed varints
                p = 0
                while p < len(data):
                    v, p = _dec_varint(data, p)
                    values.append(_scalar_from_varint(kind, v, ref))
        if repeated:
            result.setdefault(name, []).extend(values)
        elif values:
            result[name] = values[-1]
    return result


def _grpc_frame(payload):
    return b'\x00' + struct.pack('>I', len(payload)) + payload


def _grpc_unframe(data):
    """Return the payload of the first gRPC length-prefixed message."""
    if len(data) < 5:
        return None
    if data[0] & 1:
        raise DishError('compressed gRPC responses are not supported')
    length = struct.unpack('>I', data[1:5])[0]
    return data[5:5 + length]


# --------------------------------------------------------------------------
# HPACK (RFC 7541) - encoder (literals only) and full decoder
# --------------------------------------------------------------------------

def _hpack_int(value, prefix_bits, first_byte_flags):
    limit = (1 << prefix_bits) - 1
    if value < limit:
        return bytes([first_byte_flags | value])
    out = bytearray([first_byte_flags | limit])
    value -= limit
    while value >= 128:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def _hpack_str(s):
    data = s.encode()
    return _hpack_int(len(data), 7, 0) + data


def hpack_encode(headers):
    """Encode headers as 'literal without indexing' entries (no state needed)."""
    static_names = {}
    static_full = {}
    for i, (n, v) in enumerate(HPACK_STATIC, 1):
        static_names.setdefault(n, i)
        static_full.setdefault((n, v), i)
    out = bytearray()
    for name, value in headers:
        if (name, value) in static_full:
            out += _hpack_int(static_full[(name, value)], 7, 0x80)
        elif name in static_names:
            out += _hpack_int(static_names[name], 4, 0x00) + _hpack_str(value)
        else:
            out += b'\x00' + _hpack_str(name) + _hpack_str(value)
    return bytes(out)


_HUFF_TREE = None


def _huffman_tree():
    global _HUFF_TREE
    if _HUFF_TREE is None:
        tree = {}
        for sym, (code, length) in enumerate(zip(HUFFMAN_CODES, HUFFMAN_LENGTHS)):
            tree[(code, length)] = sym
        _HUFF_TREE = tree
    return _HUFF_TREE


def _huffman_decode(data):
    tree = _huffman_tree()
    out = bytearray()
    code = length = 0
    for byte in data:
        for i in range(7, -1, -1):
            code = (code << 1) | ((byte >> i) & 1)
            length += 1
            sym = tree.get((code, length))
            if sym is not None:
                if sym == 256:
                    raise DishError('EOS in huffman string')
                out.append(sym)
                code = length = 0
            elif length > 30:
                raise DishError('bad huffman code')
    return out.decode('utf-8', 'replace')


class HpackDecoder:
    def __init__(self):
        self.dynamic = []
        self.max_size = 4096

    def _size(self):
        return sum(32 + len(n) + len(v) for n, v in self.dynamic)

    def _add(self, name, value):
        self.dynamic.insert(0, (name, value))
        while self.dynamic and self._size() > self.max_size:
            self.dynamic.pop()

    def _lookup(self, idx):
        if idx <= 0:
            raise DishError('bad hpack index')
        if idx <= len(HPACK_STATIC):
            return HPACK_STATIC[idx - 1]
        idx -= len(HPACK_STATIC) + 1
        if idx >= len(self.dynamic):
            raise DishError('hpack index out of range')
        return self.dynamic[idx]

    @staticmethod
    def _int(buf, pos, prefix_bits):
        limit = (1 << prefix_bits) - 1
        value = buf[pos] & limit
        pos += 1
        if value < limit:
            return value, pos
        shift = 0
        while True:
            b = buf[pos]
            pos += 1
            value += (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                return value, pos

    def _str(self, buf, pos):
        huff = buf[pos] & 0x80
        length, pos = self._int(buf, pos, 7)
        raw = bytes(buf[pos:pos + length])
        pos += length
        return (_huffman_decode(raw) if huff else raw.decode('utf-8', 'replace')), pos

    def decode(self, buf):
        headers = []
        pos = 0
        while pos < len(buf):
            b = buf[pos]
            if b & 0x80:  # indexed
                idx, pos = self._int(buf, pos, 7)
                headers.append(self._lookup(idx))
            elif b & 0x40:  # literal with incremental indexing
                idx, pos = self._int(buf, pos, 6)
                name = self._lookup(idx)[0] if idx else None
                if name is None:
                    name, pos = self._str(buf, pos)
                value, pos = self._str(buf, pos)
                self._add(name, value)
                headers.append((name, value))
            elif b & 0x20:  # dynamic table size update
                self.max_size, pos = self._int(buf, pos, 5)
                while self.dynamic and self._size() > self.max_size:
                    self.dynamic.pop()
            else:  # literal without indexing / never indexed
                idx, pos = self._int(buf, pos, 4)
                name = self._lookup(idx)[0] if idx else None
                if name is None:
                    name, pos = self._str(buf, pos)
                value, pos = self._str(buf, pos)
                headers.append((name, value))
        return headers


# --------------------------------------------------------------------------
# transports
# --------------------------------------------------------------------------

_H2_PREFACE = b'PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n'
_DATA, _HEADERS, _RST, _SETTINGS, _PING, _GOAWAY, _WINDOW, _CONT = 0, 1, 3, 4, 6, 7, 8, 9
_WINDOW_SIZE = 16 * 1024 * 1024


def _h2_frame(ftype, flags, stream, payload=b''):
    return struct.pack('>I', len(payload))[1:] + bytes([ftype, flags]) + struct.pack('>I', stream) + payload


def _recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise DishError('connection closed by dish')
        buf += chunk
    return bytes(buf)


def _check_grpc_status(headers):
    hdrs = dict(headers)
    status = hdrs.get('grpc-status')
    if status not in (None, '0'):
        raise DishError('dish returned gRPC status %s: %s' % (status, hdrs.get('grpc-message', '')))


def call_h2c(host, port, payload, timeout):
    """One gRPC unary call over cleartext HTTP/2."""
    try:
        sock = socket.create_connection((host, port), timeout=timeout)
    except OSError as exc:
        raise DishError('cannot connect to %s:%s (%s)' % (host, port, exc))
    try:
        settings = struct.pack('>HI', 2, 0) + struct.pack('>HI', 4, _WINDOW_SIZE)
        headers = hpack_encode([
            (':method', 'POST'), (':scheme', 'http'), (':path', GRPC_PATH),
            (':authority', '%s:%s' % (host, port)), ('content-type', 'application/grpc'),
            ('te', 'trailers'), ('user-agent', 'opnsense-starlink/1.0'),
        ])
        sock.sendall(
            _H2_PREFACE
            + _h2_frame(_SETTINGS, 0, 0, settings)
            + _h2_frame(_WINDOW, 0, 0, struct.pack('>I', _WINDOW_SIZE - 65535))
            + _h2_frame(_HEADERS, 0x4, 1, headers)  # END_HEADERS
            + _h2_frame(_DATA, 0x1, 1, _grpc_frame(payload))  # END_STREAM
        )
        hpack = HpackDecoder()
        body = bytearray()
        resp_headers = []
        header_block = bytearray()
        while True:
            head = _recv_exact(sock, 9)
            length = struct.unpack('>I', b'\x00' + head[:3])[0]
            ftype, flags = head[3], head[4]
            stream = struct.unpack('>I', head[5:9])[0] & 0x7FFFFFFF
            frame = _recv_exact(sock, length) if length else b''
            if ftype == _SETTINGS:
                if not flags & 0x1:
                    sock.sendall(_h2_frame(_SETTINGS, 0x1, 0))
                continue
            if ftype == _PING:
                if not flags & 0x1:
                    sock.sendall(_h2_frame(_PING, 0x1, 0, frame))
                continue
            if ftype == _GOAWAY:
                code = struct.unpack('>I', frame[4:8])[0] if len(frame) >= 8 else -1
                if stream == 0 and code != 0:
                    raise DishError('dish closed connection (GOAWAY %d)' % code)
                if body or resp_headers:
                    break
                raise DishError('dish closed connection (GOAWAY)')
            if stream != 1:
                continue
            if ftype == _RST:
                raise DishError('dish reset the request (code %d)' % struct.unpack('>I', frame[:4])[0])
            if ftype == _DATA:
                if flags & 0x8:  # padded
                    pad = frame[0]
                    frame = frame[1:len(frame) - pad]
                body += frame
                if length:
                    inc = struct.pack('>I', length)
                    sock.sendall(_h2_frame(_WINDOW, 0, 0, inc) + _h2_frame(_WINDOW, 0, 1, inc))
            elif ftype in (_HEADERS, _CONT):
                if ftype == _HEADERS:
                    if flags & 0x8:
                        pad = frame[0]
                        frame = frame[1:len(frame) - pad]
                    if flags & 0x20:  # priority
                        frame = frame[5:]
                    end_stream_on_headers = bool(flags & 0x1)
                header_block += frame
                if flags & 0x4:  # END_HEADERS
                    resp_headers += hpack.decode(bytes(header_block))
                    header_block = bytearray()
                    if end_stream_on_headers:
                        break
                continue
            if flags & 0x1:  # END_STREAM on DATA
                break
        hdrs = dict(resp_headers)
        if hdrs.get(':status', '200') != '200':
            raise DishError('HTTP status %s from dish' % hdrs.get(':status'))
        _check_grpc_status(resp_headers)
        msg = _grpc_unframe(bytes(body))
        if msg is None:
            raise DishError('empty response from dish')
        return msg
    except socket.timeout:
        raise DishError('timed out talking to %s:%s' % (host, port))
    except OSError as exc:
        raise DishError('network error talking to %s:%s (%s)' % (host, port, exc))
    finally:
        try:
            sock.close()
        except OSError:
            pass


def call_grpcweb(host, port, payload, timeout):
    """One gRPC-Web unary call over HTTP/1.1."""
    try:
        conn = http.client.HTTPConnection(host, port, timeout=timeout)
        conn.request('POST', GRPC_PATH, body=_grpc_frame(payload), headers={
            'Content-Type': 'application/grpc-web+proto',
            'Accept': 'application/grpc-web+proto',
            'X-Grpc-Web': '1',
            'User-Agent': 'opnsense-starlink/1.0',
        })
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
    except socket.timeout:
        raise DishError('timed out talking to %s:%s' % (host, port))
    except (OSError, http.client.HTTPException) as exc:
        raise DishError('cannot reach gRPC-Web endpoint %s:%s (%s)' % (host, port, exc))
    if resp.status != 200:
        raise DishError('HTTP status %s from gRPC-Web endpoint' % resp.status)
    headers = [(k.lower(), v) for k, v in resp.getheaders()]
    _check_grpc_status(headers)
    msg = None
    pos = 0
    while pos + 5 <= len(data):
        flag = data[pos]
        length = struct.unpack('>I', data[pos + 1:pos + 5])[0]
        chunk = data[pos + 5:pos + 5 + length]
        pos += 5 + length
        if flag & 0x80:  # trailers
            trailers = []
            for line in chunk.decode('utf-8', 'replace').split('\r\n'):
                if ':' in line:
                    k, v = line.split(':', 1)
                    trailers.append((k.strip().lower(), v.strip()))
            _check_grpc_status(trailers)
        elif msg is None:
            msg = chunk
    if msg is None:
        raise DishError('empty gRPC-Web response')
    return msg


# --------------------------------------------------------------------------
# high level client
# --------------------------------------------------------------------------

class Dish:
    def __init__(self, host='192.168.100.1', port=9200, web_port=9201, transport='auto', timeout=10):
        self.host = host
        self.port = int(port)
        self.web_port = int(web_port)
        self.transport = transport
        self.timeout = float(timeout)
        self.used_transport = None

    def handle(self, request):
        """Send a Request dict, return the decoded Response dict."""
        payload = encode('Request', request)
        errors = []
        order = {'h2c': ['h2c'], 'grpcweb': ['grpcweb']}.get(self.transport, ['h2c', 'grpcweb'])
        for name in order:
            try:
                if name == 'h2c':
                    raw = call_h2c(self.host, self.port, payload, self.timeout)
                else:
                    raw = call_grpcweb(self.host, self.web_port, payload, self.timeout)
                self.used_transport = name
                break
            except DishError as exc:
                errors.append('%s: %s' % (name, exc))
        else:
            raise DishError('; '.join(errors))
        resp = decode('Response', raw)
        status = resp.get('status') or {}
        if status.get('code'):
            raise DishError('dish error %s: %s' % (status.get('code'), status.get('message', '')))
        return resp

    # convenience wrappers
    def get_status(self):
        return self.handle({'get_status': {}}).get('dish_get_status', {})

    def get_history(self):
        return self.handle({'get_history': {}}).get('dish_get_history', {})

    def get_obstruction_map(self):
        return self.handle({'dish_get_obstruction_map': {}}).get('dish_get_obstruction_map', {})

    def get_config(self):
        return self.handle({'dish_get_config': {}}).get('dish_get_config', {}).get('dish_config', {})

    def get_location(self):
        return self.handle({'get_location': {}}).get('get_location', {})

    def reboot(self):
        self.handle({'reboot': {}})

    def stow(self, unstow=False):
        self.handle({'dish_stow': {'unstow': True} if unstow else {}})

    def set_power_save(self, enable, start_utc_minutes=0, duration_minutes=1):
        if enable:
            if not 0 <= start_utc_minutes <= 1439 or not 1 <= duration_minutes <= 1440:
                raise DishError('sleep start/duration out of range')
            req = {'power_save_start_minutes': start_utc_minutes,
                   'power_save_duration_minutes': duration_minutes,
                   'enable_power_save': True}
        else:
            # the dish rejects a zero duration, even when disabling
            req = {'power_save_duration_minutes': 1, 'enable_power_save': False}
        self.handle({'dish_power_save': req})

    def inhibit_gps(self, inhibit):
        self.handle({'dish_inhibit_gps': {'inhibit_gps': bool(inhibit)}})

    def set_snow_melt(self, mode):
        self.handle({'dish_set_config': {'dish_config': {
            'snow_melt_mode': mode, 'apply_snow_melt_mode': True}}})
