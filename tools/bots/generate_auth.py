#!/usr/bin/env python3
"""Gera apenas verificador derivado dos repository secrets para o painel estático.

GitHub Pages não é um backend de autenticação: esta barreira é de conveniência
para um painel que mostra apenas dados PÚBLICOS do repositório. Um PIN curto
pode ser descoberto por força bruta offline. Não usar para conteúdo privado.
"""
import hashlib
import json
import os
import secrets
import sys
from pathlib import Path

ITERATIONS = 600_000


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Uso: generate_auth.py <pasta do painel>")
    username = os.environ.get("QSE_DASH_USER", "")
    password = os.environ.get("QSE_DASH_PASSWORD", "")
    if not username or not password:
        raise SystemExit("Secrets USER e PASSWORD ausentes. O painel NÃO será publicado sem login.")
    if "\x00" in username or "\x00" in password:
        raise SystemExit("Credenciais não podem conter caracteres nulos.")
    salt = secrets.token_bytes(24)
    secret_input = (username.strip() + "\x00" + password).encode("utf-8")
    digest = hashlib.pbkdf2_hmac("sha256", secret_input, salt, ITERATIONS)
    target = Path(sys.argv[1])
    target.mkdir(parents=True, exist_ok=True)
    output = target / "auth.json"
    output.write_text(
        json.dumps(
            {
                "version": 1,
                "algorithm": "PBKDF2-SHA256",
                "iterations": ITERATIONS,
                "salt": salt.hex(),
                "digest": digest.hex(),
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print("QSE Command Center: verificador gerado sem gravar as credenciais.")


if __name__ == "__main__":
    main()
