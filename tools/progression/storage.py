"""Saídas novas e backups literais. Não substitui o ConfigFile/user:// do jogo."""
import os
import hashlib
import re
from pathlib import Path
import tempfile

from .codec import canonical, loads, require
from .saves import validate_save


def write_new_file(path, raw):
    """Publicação atômica sem sobrescrever: link do temporário para destino inexistente."""
    path = Path(path)
    fd, temporary = tempfile.mkstemp(prefix=".progression-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path)  # Falha se destino existe; nunca os.replace em save antigo.
        if hasattr(os, "O_DIRECTORY"):
            directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
    finally:
        Path(temporary).unlink(missing_ok=True)


def write_migration_bundle(rules, sources, result, output_directory):
    """Reserva diretório exclusivo; status.complete só aparece após todos os arquivos."""
    if result.save is not None:
        validate_save(rules, result.save)
    require({name: hashlib.sha256(raw).hexdigest() for name, raw in sources.items()} == result.report.get("source_sha256"), "migration_source_mismatch", "Backups não correspondem às fontes migradas")
    destination = Path(output_directory)
    destination.mkdir(mode=0o700, parents=False, exist_ok=False)
    originals = destination / "originals"
    originals.mkdir(mode=0o700)
    for index, (name, raw) in enumerate(sorted(sources.items()), 1):
        # Não usar nomes de entrada como destinos, evitando caminhos maliciosos.
        write_new_file(originals / f"source_{index:02d}.bin", raw)
    index = {f"source_{i:02d}.bin": name for i, name in enumerate(sorted(sources), 1)}
    write_new_file(destination / "originals_index.json", canonical(index) + b"\n")
    write_new_file(destination / "migration_report.json", canonical(result.report) + b"\n")
    if result.save is not None:
        write_new_file(destination / "save.v2.json", canonical(result.save) + b"\n")
    write_new_file(destination / "status.complete", b"migration_bundle_complete\n")
    return destination


def inspect_migration_bundle(rules, directory):
    directory = Path(directory)
    require((directory / "status.complete").is_file() and (directory / "status.complete").read_bytes() == b"migration_bundle_complete\n", "incomplete_migration", "Bundle incompleto; originais não devem ser substituídos")
    index = loads((directory / "originals_index.json").read_bytes())
    report = loads((directory / "migration_report.json").read_bytes())
    require(isinstance(index, dict) and isinstance(report, dict) and isinstance(report.get("source_sha256"), dict), "invalid_migration_bundle", "Índice/relatório inválido")
    require(all(isinstance(name, str) and isinstance(source, str) for name, source in index.items()), "invalid_migration_bundle", "Nomes de backup/fontes inválidos")
    require(len(set(index.values())) == len(index) and set(index.values()) == set(report["source_sha256"]), "invalid_migration_bundle", "Índice não corresponde às fontes")
    for backup, source in index.items():
        require(re.fullmatch(r"source_[0-9]{2,}\.bin", backup) is not None, "invalid_migration_bundle", "Nome de backup inválido")
        path = (directory / "originals" / backup).resolve()
        require(path.is_relative_to((directory / "originals").resolve()), "invalid_migration_bundle", "Backup fora do bundle")
        require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == report["source_sha256"][source], "backup_checksum_mismatch", "Backup de origem diverge do checksum")
    save_path = directory / "save.v2.json"
    if report.get("status") == "quarantined":
        require(not save_path.exists(), "invalid_migration_bundle", "Save corrompido não pode ter progresso novo criado")
    else:
        require(report.get("status") in ("migrated_unverified", "already_current") and save_path.is_file(), "invalid_migration_bundle", "Resultado da migração inválido")
        from .saves import load_save
        load_save(rules, save_path.read_bytes())
    return {"status": report["status"], "originals_verified": len(index), "save_present": save_path.is_file()}
