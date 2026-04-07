#!/usr/bin/env python3
"""
Minimal fragmented MP4 (CMAF) to regular MP4 remuxer.
Converts Reddit's fMP4 video files into QuickTime 7-compatible MP4.

Usage: python3 remux_fmp4.py input.mp4 output.mp4

No external dependencies - uses only Python standard library.
"""
import sys
import struct
import io

def read_box(f):
    """Read an MP4 box header. Returns (box_type, box_data, box_size) or None."""
    header = f.read(8)
    if len(header) < 8:
        return None
    size = struct.unpack('>I', header[:4])[0]
    box_type = header[4:8]
    if size == 1:  # 64-bit extended size
        ext = f.read(8)
        size = struct.unpack('>Q', ext)[0]
        data = f.read(size - 16)
    elif size == 0:  # box extends to EOF
        data = f.read()
    else:
        data = f.read(size - 8)
    return box_type, data, size

def parse_boxes(data):
    """Parse all top-level boxes from bytes."""
    boxes = []
    f = io.BytesIO(data)
    while True:
        box = read_box(f)
        if box is None:
            break
        boxes.append(box)
    return boxes

def find_box(boxes, box_type):
    """Find first box of given type."""
    for btype, bdata, bsize in boxes:
        if btype == box_type:
            return bdata
    return None

def write_box(f, box_type, data):
    """Write an MP4 box."""
    size = len(data) + 8
    f.write(struct.pack('>I', size))
    f.write(box_type)
    f.write(data)

def remux_fmp4(input_path, output_path):
    """Convert fragmented MP4 to regular MP4 for QuickTime 7 compatibility."""
    with open(input_path, 'rb') as f:
        file_data = f.read()

    # Parse top-level boxes
    top_boxes = parse_boxes(file_data)
    box_types = [b[0] for b in top_boxes]

    # Check if this is actually fragmented (has moof boxes)
    has_moof = b'moof' in box_types
    if not has_moof:
        # Already a regular MP4, just copy
        import shutil
        shutil.copy2(input_path, output_path)
        return True

    # Find the init segment (ftyp + moov)
    ftyp_data = find_box(top_boxes, b'ftyp')
    moov_data = find_box(top_boxes, b'moov')

    if not moov_data:
        print("ERROR: No moov box found", file=sys.stderr)
        return False

    # Collect all mdat samples from moof+mdat pairs
    all_samples = bytearray()
    sample_sizes = []
    sample_durations = []
    sample_flags = []
    default_sample_duration = 0
    default_sample_size = 0

    for i, (btype, bdata, bsize) in enumerate(top_boxes):
        if btype == b'moof':
            moof_boxes = parse_boxes(bdata)
            traf_data = find_box(moof_boxes, b'traf')
            if traf_data:
                traf_boxes = parse_boxes(traf_data)
                # Parse tfhd for defaults
                tfhd_data = find_box(traf_boxes, b'tfhd')
                if tfhd_data:
                    tfhd_flags = struct.unpack('>I', b'\x00' + tfhd_data[0:3])[0]
                    offset = 4  # skip track_id
                    if tfhd_flags & 0x01: offset += 8  # base_data_offset
                    if tfhd_flags & 0x02: offset += 4  # sample_description_index
                    if tfhd_flags & 0x08:
                        default_sample_duration = struct.unpack('>I', tfhd_data[offset:offset+4])[0]
                        offset += 4
                    if tfhd_flags & 0x10:
                        default_sample_size = struct.unpack('>I', tfhd_data[offset:offset+4])[0]

                # Parse trun for sample info
                trun_data = find_box(traf_boxes, b'trun')
                if trun_data:
                    trun_flags = struct.unpack('>I', b'\x00' + trun_data[0:3])[0]
                    sample_count = struct.unpack('>I', trun_data[4:8])[0]
                    offset = 8
                    if trun_flags & 0x01: offset += 4  # data_offset
                    if trun_flags & 0x04: offset += 4  # first_sample_flags

                    for s in range(sample_count):
                        dur = default_sample_duration
                        sz = default_sample_size
                        flg = 0
                        if trun_flags & 0x100:
                            dur = struct.unpack('>I', trun_data[offset:offset+4])[0]
                            offset += 4
                        if trun_flags & 0x200:
                            sz = struct.unpack('>I', trun_data[offset:offset+4])[0]
                            offset += 4
                        if trun_flags & 0x400:
                            flg = struct.unpack('>I', trun_data[offset:offset+4])[0]
                            offset += 4
                        if trun_flags & 0x800:
                            offset += 4  # composition_time_offset
                        sample_durations.append(dur)
                        sample_sizes.append(sz)
                        sample_flags.append(flg)

        elif btype == b'mdat':
            all_samples.extend(bdata)

    if not sample_sizes:
        print("ERROR: No samples found in fragments", file=sys.stderr)
        return False

    total_samples = len(sample_sizes)
    total_duration = sum(sample_durations)

    # Parse original moov to get track parameters
    moov_boxes = parse_boxes(moov_data)
    trak_data = find_box(moov_boxes, b'trak')
    mvhd_data = find_box(moov_boxes, b'mvhd')

    # Get timescale from mvhd
    timescale = 1000
    if mvhd_data:
        version = mvhd_data[0]
        if version == 0:
            timescale = struct.unpack('>I', mvhd_data[4+8:4+12])[0]
        else:
            timescale = struct.unpack('>I', mvhd_data[4+16:4+20])[0]

    # Build the stbl (sample table) for the regular MP4
    # We need: stsd (from original), stts, stsz, stsc, stco, stss

    # Get original stsd
    original_stsd = None
    if trak_data:
        trak_boxes = parse_boxes(trak_data)
        mdia_data = find_box(trak_boxes, b'mdia')
        if mdia_data:
            mdia_boxes = parse_boxes(mdia_data)
            minf_data = find_box(mdia_boxes, b'minf')
            if minf_data:
                minf_boxes = parse_boxes(minf_data)
                stbl_data = find_box(minf_boxes, b'stbl')
                if stbl_data:
                    stbl_boxes = parse_boxes(stbl_data)
                    original_stsd = find_box(stbl_boxes, b'stsd')

    if not original_stsd:
        print("ERROR: Could not find stsd in moov", file=sys.stderr)
        return False

    # Build stts (time-to-sample)
    stts = io.BytesIO()
    stts.write(struct.pack('>I', 0))  # version + flags
    # Compress runs
    runs = []
    if sample_durations:
        cur_dur = sample_durations[0]
        cur_count = 1
        for d in sample_durations[1:]:
            if d == cur_dur:
                cur_count += 1
            else:
                runs.append((cur_count, cur_dur))
                cur_dur = d
                cur_count = 1
        runs.append((cur_count, cur_dur))
    stts.write(struct.pack('>I', len(runs)))
    for count, dur in runs:
        stts.write(struct.pack('>II', count, dur))

    # Build stsz (sample sizes)
    stsz = io.BytesIO()
    stsz.write(struct.pack('>I', 0))  # version + flags
    stsz.write(struct.pack('>I', 0))  # sample_size (0 = variable)
    stsz.write(struct.pack('>I', total_samples))
    for sz in sample_sizes:
        stsz.write(struct.pack('>I', sz))

    # Build stsc (sample-to-chunk) - all samples in one chunk
    stsc = io.BytesIO()
    stsc.write(struct.pack('>I', 0))  # version + flags
    stsc.write(struct.pack('>I', 1))  # entry count
    stsc.write(struct.pack('>III', 1, total_samples, 1))

    # Build stco (chunk offsets) - will be filled after we know the moov size
    stco_placeholder = io.BytesIO()
    stco_placeholder.write(struct.pack('>I', 0))  # version + flags
    stco_placeholder.write(struct.pack('>I', 1))  # entry count
    stco_placeholder.write(struct.pack('>I', 0))  # placeholder offset

    # Build stss (sync samples / keyframes)
    stss = io.BytesIO()
    stss.write(struct.pack('>I', 0))  # version + flags
    sync_samples = []
    for i, flg in enumerate(sample_flags):
        # In trun flags, bit 16 (0x10000) = sample_is_non_sync
        if not (flg & 0x10000):
            sync_samples.append(i + 1)  # 1-indexed
    if not sync_samples:
        sync_samples = [1]  # at least first frame
    stss.write(struct.pack('>I', len(sync_samples)))
    for s in sync_samples:
        stss.write(struct.pack('>I', s))

    # Assemble stbl
    stbl = io.BytesIO()
    write_box(stbl, b'stsd', original_stsd)
    write_box(stbl, b'stts', stts.getvalue())
    write_box(stbl, b'stsz', stsz.getvalue())
    write_box(stbl, b'stsc', stsc.getvalue())
    write_box(stbl, b'stco', stco_placeholder.getvalue())
    write_box(stbl, b'stss', stss.getvalue())

    # Rebuild minf with new stbl
    new_minf = io.BytesIO()
    if minf_data:
        for btype, bdata, bsize in parse_boxes(minf_data):
            if btype != b'stbl':
                write_box(new_minf, btype, bdata)
    write_box(new_minf, b'stbl', stbl.getvalue())

    # Rebuild mdia with new minf
    new_mdia = io.BytesIO()
    if mdia_data:
        for btype, bdata, bsize in parse_boxes(mdia_data):
            if btype == b'minf':
                write_box(new_mdia, btype, new_minf.getvalue())
            elif btype == b'mdhd':
                # Update duration in mdhd
                mdhd = bytearray(bdata)
                version = mdhd[0]
                if version == 0:
                    struct.pack_into('>I', mdhd, 4+8+4, total_duration)
                else:
                    struct.pack_into('>Q', mdhd, 4+16+4, total_duration)
                write_box(new_mdia, btype, bytes(mdhd))
            else:
                write_box(new_mdia, btype, bdata)

    # Rebuild trak with new mdia
    new_trak = io.BytesIO()
    if trak_data:
        for btype, bdata, bsize in parse_boxes(trak_data):
            if btype == b'mdia':
                write_box(new_trak, btype, new_mdia.getvalue())
            elif btype == b'tkhd':
                # Update duration in tkhd
                tkhd = bytearray(bdata)
                version = tkhd[0]
                dur_in_movie_timescale = total_duration  # approximate
                if version == 0:
                    struct.pack_into('>I', tkhd, 4+8+4, dur_in_movie_timescale)
                else:
                    struct.pack_into('>Q', tkhd, 4+16+8, dur_in_movie_timescale)
                write_box(new_trak, btype, bytes(tkhd))
            else:
                write_box(new_trak, btype, bdata)

    # Rebuild moov
    new_moov = io.BytesIO()
    for btype, bdata, bsize in moov_boxes:
        if btype == b'trak':
            write_box(new_moov, btype, new_trak.getvalue())
        elif btype == b'mvhd':
            mvhd = bytearray(bdata)
            version = mvhd[0]
            if version == 0:
                struct.pack_into('>I', mvhd, 4+8+4, total_duration)
            else:
                struct.pack_into('>Q', mvhd, 4+16+4, total_duration)
            write_box(new_moov, btype, bytes(mvhd))
        elif btype == b'mvex':
            pass  # Skip mvex (fragment extension) - not needed in regular MP4
        else:
            write_box(new_moov, btype, bdata)

    moov_bytes = new_moov.getvalue()

    # Calculate mdat offset (ftyp + moov + mdat header)
    ftyp_box_size = len(ftyp_data) + 8 if ftyp_data else 0
    moov_box_size = len(moov_bytes) + 8
    mdat_header_size = 8
    mdat_data_offset = ftyp_box_size + moov_box_size + mdat_header_size

    # Fix stco offset - find it in the moov_bytes
    stco_marker = struct.pack('>I', 0) + struct.pack('>I', 1) + struct.pack('>I', 0)  # version + count + placeholder
    stco_pos = moov_bytes.find(stco_marker)
    if stco_pos >= 0:
        moov_bytes = bytearray(moov_bytes)
        struct.pack_into('>I', moov_bytes, stco_pos + 8, mdat_data_offset)
        moov_bytes = bytes(moov_bytes)

    # Write output: ftyp + moov + mdat
    with open(output_path, 'wb') as f:
        # Write ftyp (use standard mp4 ftyp)
        ftyp_out = struct.pack('>4s', b'mp41') + struct.pack('>I', 0) + b'isom' + b'mp41'
        write_box(f, b'ftyp', ftyp_out)
        # Recalculate mdat offset with new ftyp
        new_ftyp_size = len(ftyp_out) + 8
        mdat_data_offset = new_ftyp_size + moov_box_size + mdat_header_size
        # Fix stco again
        moov_bytes = bytearray(moov_bytes)
        if stco_pos >= 0:
            struct.pack_into('>I', moov_bytes, stco_pos + 8, mdat_data_offset)
        moov_bytes = bytes(moov_bytes)

        write_box(f, b'moov', moov_bytes)
        write_box(f, b'mdat', bytes(all_samples))

    print(f"Remuxed: {total_samples} samples, {total_duration}/{timescale}s", file=sys.stderr)
    return True

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.mp4 output.mp4", file=sys.stderr)
        sys.exit(1)
    if remux_fmp4(sys.argv[1], sys.argv[2]):
        sys.exit(0)
    else:
        sys.exit(1)
