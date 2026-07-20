"""Servidor estatico com os cabecalhos de isolamento que o WebAssembly exige.

O shinylive precisa de SharedArrayBuffer, que so fica disponivel quando a pagina
esta "cross-origin isolated". Isso exige os dois cabecalhos abaixo. Sem eles o
webR cai no canal PostMessage e a interface nao monta.

O mesmo vale na publicacao: o Cloudflare Pages precisa de um arquivo _headers.
"""
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()


if __name__ == "__main__":
    raiz = sys.argv[1]
    porta = int(sys.argv[2])
    import os
    os.chdir(raiz)
    ThreadingHTTPServer(("0.0.0.0", porta), Handler).serve_forever()
