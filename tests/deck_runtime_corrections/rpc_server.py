"""Loopback-only HTTP replies for SupabaseClient parsing. No database or credentials."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        data=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))) or '{}')
        cases={
            'own':(200,{'error':'cannot_report_own'}),
            'repeat':(200,{'error':'already_reported'}),
            'reason':(200,{'error':'invalid_reason'}),
            'forbidden_rpc':(200,{'error':'forbidden'}),
            'forbidden_http':(403,{'code':'42501'}),
            'unauthorized':(401,{'code':'PGRST301'}),
            'missing':(404,{'code':'PGRST202'}),
            'ok':(200,{'reported':True}),
        }
        status,body=(400,{'error':'invalid_grant','error_code':'invalid_credentials'}) if self.path.startswith('/auth/') else cases[data.get('case','ok')]
        payload=json.dumps(body).encode()
        self.send_response(status);self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
ThreadingHTTPServer(('127.0.0.1',18856),Handler).serve_forever()
