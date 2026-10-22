# claude-toolbox: Claude Code cloud sessions re-terminate TLS at an egress proxy whose CA
# is in SSL_CERT_FILE. edge_tts hard-codes certifi.where(), so point certifi there too.
# No-op when SSL_CERT_FILE is unset (e.g. on a PC).
import os

_ca = os.environ.get("SSL_CERT_FILE")
if _ca and os.path.isfile(_ca):
    try:
        import certifi
        certifi.where = lambda: _ca
    except ImportError:
        pass
