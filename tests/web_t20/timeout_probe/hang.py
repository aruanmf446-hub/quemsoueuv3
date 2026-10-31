import socket, threading, time, sys
PORT=int(sys.argv[1]); SILENT=len(sys.argv)>2
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', PORT)); s.listen(16)
def hold(c):
    try:
        c.recv(65536)
        if SILENT: time.sleep(600)
        c.sendall(b"HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 100\r\n\r\n")
        time.sleep(600)
    except Exception: pass
while True:
    c, _ = s.accept(); threading.Thread(target=hold, args=(c,), daemon=True).start()
