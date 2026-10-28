"""Referência isolada de progressão. Não importa Godot nem acessa rede."""

from .codec import ProgressionError
from .rules import Rules
from .engine import new_state, start_phase, record_checkpoint, complete_phase, equip_character

__all__ = ["ProgressionError", "Rules", "new_state", "start_phase", "record_checkpoint", "complete_phase", "equip_character"]
