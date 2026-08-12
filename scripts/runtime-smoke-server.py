#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse
import time


MP4 = (
    b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom"
    + b"SpectraGrab-runtime-direct" * 128
)
TRANSPORT_STREAM = bytes([0x47]) + bytes(187)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/direct.mp4":
            return self.send_payload("video/mp4", MP4)
        if self.path == "/slow.mp4":
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(len(MP4) * 200))
            self.end_headers()
            try:
                for _ in range(200):
                    self.wfile.write(MP4)
                    self.wfile.flush()
                    time.sleep(0.05)
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        if self.path == "/vod/master.m3u8":
            return self.send_payload(
                "application/vnd.apple.mpegurl",
                b"#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=128000\nmedia.m3u8\n",
            )
        if self.path == "/vod/media.m3u8":
            return self.send_payload(
                "application/vnd.apple.mpegurl",
                b"#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nsegment.ts\n#EXT-X-ENDLIST\n",
            )
        if self.path == "/vod/segment.ts":
            return self.send_payload("video/mp2t", TRANSPORT_STREAM * 8)
        if self.path == "/live/live.m3u8":
            return self.send_payload(
                "application/vnd.apple.mpegurl",
                b"#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:1\n#EXTINF:1,\nsegment.ts\n",
            )
        if self.path == "/live/segment.ts":
            return self.send_payload("video/mp2t", TRANSPORT_STREAM * 8)
        self.send_error(404)

    def send_payload(self, content_type, payload):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        print(f"{self.address_string()} {format % args}", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    ThreadingHTTPServer(("0.0.0.0", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()