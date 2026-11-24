#!/usr/bin/env python3
"""
Regenerate net/starlink/src/opnsense/scripts/starlink/starlink_proto.py from
the Starlink .proto files, for when SpaceX adds or renumbers fields.

  pip install grpcio-tools hpack
  git clone --depth 1 https://github.com/Eitol/starlink-client
  python3 tools/gen_schema.py starlink-client/proto net/starlink/src/opnsense/scripts/starlink/starlink_proto.py

Only the request/response fields the plugin uses (and the messages they reach)
are included, to keep the file small.
"""

import glob
import importlib
import os
import pprint
import subprocess
import sys
import tempfile

REQ_FIELDS = {'id', 'get_status', 'get_history', 'get_device_info', 'reboot', 'get_location', 'dish_stow',
              'dish_get_obstruction_map', 'dish_set_config', 'dish_get_config', 'dish_power_save',
              'dish_inhibit_gps'}
RESP_FIELDS = {'id', 'status', 'api_version', 'get_device_info', 'reboot', 'get_location', 'dish_get_history',
               'dish_get_status', 'dish_get_obstruction_map', 'dish_stow', 'dish_set_config', 'dish_get_config',
               'dish_inhibit_gps'}

HEADER = '''"""Protocol data tables for the Starlink dish client.

MESSAGES/ENUMS: subset of the SpaceX.API.Device protobuf schema, generated from
publicly extracted .proto files (github.com/Eitol/starlink-client,
MIT licence, see THIRD_PARTY_NOTICES.md). Regenerate with tools/gen_schema.py.
HPACK tables: RFC 7541 Appendix A and B.
"""

'''


def main(proto_dir, out_path):
    import grpc_tools
    from google.protobuf.descriptor import FieldDescriptor as FD
    import hpack.huffman_constants as huff
    from hpack.table import HeaderTable

    gen = tempfile.mkdtemp()
    include = os.path.join(os.path.dirname(grpc_tools.__file__), '_proto')
    protos = [os.path.relpath(p, proto_dir) for p in glob.glob(os.path.join(proto_dir, '**/*.proto'), recursive=True)]
    subprocess.check_call([sys.executable, '-m', 'grpc_tools.protoc', '-I', proto_dir, '-I', include,
                           '--python_out', gen] + protos)
    sys.path.insert(0, gen)
    device_pb2 = importlib.import_module('spacex.api.device.device_pb2')
    pool = device_pb2.DESCRIPTOR.pool

    kind = {FD.TYPE_DOUBLE: 'double', FD.TYPE_FLOAT: 'float', FD.TYPE_INT64: 'int64', FD.TYPE_UINT64: 'uint64',
            FD.TYPE_INT32: 'int32', FD.TYPE_FIXED64: 'fixed64', FD.TYPE_FIXED32: 'fixed32', FD.TYPE_BOOL: 'bool',
            FD.TYPE_STRING: 'string', FD.TYPE_MESSAGE: 'msg', FD.TYPE_BYTES: 'bytes', FD.TYPE_UINT32: 'uint32',
            FD.TYPE_ENUM: 'enum', FD.TYPE_SFIXED32: 'sfixed32', FD.TYPE_SFIXED64: 'sfixed64',
            FD.TYPE_SINT32: 'sint32', FD.TYPE_SINT64: 'sint64'}
    msgs, enums = {}, {}

    def short(name):
        return name.replace('SpaceX.API.Device.', '').replace('SpaceX.API.', '')

    def walk(m, only=None):
        name = short(m.full_name)
        if name in msgs:
            return
        msgs[name] = {}
        for f in m.fields:
            if only and f.name not in only:
                continue
            ref = None
            if f.message_type:
                ref = short(f.message_type.full_name)
            if f.enum_type:
                ref = short(f.enum_type.full_name)
                enums[ref] = {v.number: v.name for v in f.enum_type.values}
            repeated = f.is_repeated if hasattr(f, 'is_repeated') else f.label == FD.LABEL_REPEATED
            msgs[name][f.number] = (f.name, kind[f.type], bool(repeated), ref)
            if f.message_type:
                walk(f.message_type)

    walk(pool.FindMessageTypeByName('SpaceX.API.Device.Request'), REQ_FIELDS)
    walk(pool.FindMessageTypeByName('SpaceX.API.Device.Response'), RESP_FIELDS)
    static = [(k.decode(), v.decode()) for k, v in HeaderTable.STATIC_TABLE]

    with open(out_path, 'w') as fh:
        fh.write(HEADER)
        fh.write('MESSAGES = ' + pprint.pformat(msgs, width=120, compact=True) + '\n\n')
        fh.write('ENUMS = ' + pprint.pformat(enums, width=120, compact=True) + '\n')
        fh.write('\nHPACK_STATIC = %r\n' % (static,))
        fh.write('\nHUFFMAN_CODES = %r\n' % (list(huff.REQUEST_CODES),))
        fh.write('\nHUFFMAN_LENGTHS = %r\n' % (list(huff.REQUEST_CODES_LENGTH),))
    print('wrote %s: %d messages, %d enums' % (out_path, len(msgs), len(enums)))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
