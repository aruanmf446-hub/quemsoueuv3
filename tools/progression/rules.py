"""Regras versionadas; categorias não são inferidas da presença de um modelo."""
from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType

from .codec import ROOT, RULES_VERSION, Contracts, loads, require


@dataclass(frozen=True)
class Phase:
    id: str
    order: int
    checkpoint_ids: tuple
    boss_id: str | None


@dataclass(frozen=True)
class Character:
    id: str
    classification: str
    scope: str
    initially_unlocked: bool
    required_achievement: str | None


class Rules:
    def __init__(self, root=ROOT):
        root = Path(root)
        self.contracts = Contracts(root)
        data = loads((root / "data/progression/rules.v2.json").read_bytes())
        self.contracts.validate("rules", data)
        require(data["schema_version"] == 2 and data["rules_version"] == RULES_VERSION, "rules_version_mismatch", "Versão de regras desconhecida")
        for path, expected in data["content_sources_sha256"].items():
            target = (root / path).resolve()
            require(target.is_relative_to(root.resolve()), "invalid_content_path", "Referência fora do projeto")
            require(target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() == expected, "content_changed", "Fonte de conteúdo diverge da versão fixada: " + path)
        phases = [Phase(p["id"], p["order"], tuple(p["checkpoint_ids"]), p["boss_id"]) for p in data["phases"]]
        require([p.id for p in phases] == [f"desert_phase_{i:02d}" for i in range(1, 11)] and [p.order for p in phases] == list(range(1, 11)), "invalid_phase_order", "Exigem-se dez fases estáveis e ordenadas")
        require(all(p.boss_id is None for p in phases[:-1]) and phases[-1].boss_id == "malagueta", "invalid_boss_rule", "Malagueta é o chefe final da fase 10")
        checkpoints = [c for p in phases for c in p.checkpoint_ids]
        require(len(set(checkpoints)) == len(checkpoints) and all(p.checkpoint_ids for p in phases), "invalid_checkpoints", "Checkpoints incompletos ou repetidos")
        characters = [Character(c["id"], c["classification"], c["scope"], c["lobby_initially_unlocked"], c["required_achievement_id"]) for c in data["characters"]]
        require(len({c.id for c in characters}) == len(characters), "duplicate_character", "Personagem duplicado")
        allowed = {"playable_hero", "unlockable_hero", "common_enemy", "miniboss", "final_boss", "campaign_only_character"}
        require(all(c.classification in allowed for c in characters), "invalid_classification", "Categoria desconhecida")
        grouped = {"playable_heroes": "playable_hero", "unlockable_heroes": "unlockable_hero", "common_enemies": "common_enemy", "minibosses": "miniboss", "final_bosses": "final_boss", "campaign_only_characters": "campaign_only_character"}
        require(set(data["classifications"]) == set(grouped), "incomplete_classifications", "Expor todas as categorias, inclusive as vazias")
        for group, kind in grouped.items():
            require(data["classifications"][group] == [c.id for c in characters if c.classification == kind], "classification_mismatch", group)
        self.characters = MappingProxyType({c.id: c for c in characters})
        self.phases = tuple(phases)
        self.phase_ids = tuple(p.id for p in phases)
        self.phase_by_id = MappingProxyType({p.id: p for p in phases})
        self.initial_characters = tuple(c.id for c in characters if c.initially_unlocked)
        self.campaign_id = data["campaign_id"]
        self.protagonist_id = data["protagonist_id"]
        self.achievement_id = data["achievement_id"]
        self.unlock_character_id = data["unlock_character_id"]
        require((self.campaign_id, self.protagonist_id, self.achievement_id, self.unlock_character_id) == ("desert_campaign", "el_fuego", "desert_campaign_completed", "el_fuego"), "invalid_campaign_rule", "Regra de campanha divergente")
        require(self.characters["cactus"].classification == "common_enemy" and self.characters["malagueta"].classification == "final_boss", "invalid_hostile_role", "Papéis obrigatórios divergentes")
        require(self.characters["el_fuego"].classification == "unlockable_hero" and not self.characters["el_fuego"].initially_unlocked and self.characters["el_fuego"].required_achievement == self.achievement_id, "invalid_fuego_rule", "El Fuego inicia bloqueado no lobby")
        require(all(c.classification == "playable_hero" and c.required_achievement is None for c in characters if c.initially_unlocked), "invalid_initial_unlock", "Só heróis iniciais podem começar liberados")
        previous = loads((root / "data/planning/character_registry.json").read_bytes())
        require(set(self.characters) == {c["id"] for c in previous["entries"]}, "catalog_changed", "Não inventar/remover identidades na mesma versão de regras")
        require(self.initial_characters == tuple(c["id"] for c in previous["entries"] if c["lobby"]["initially_unlocked"]), "catalog_changed", "Heróis iniciais divergem da fonte preservada")
        for phase in phases:
            source = loads((root / f"data/planning/desert/phase_{phase.order:02d}.json").read_bytes())
            require(phase.checkpoint_ids == tuple(c["id"] for c in source["checkpoints_planned"]), "content_changed", "Checkpoints divergem do planejamento fixado")

    def grants(self, completed):
        done = tuple(completed) == self.phase_ids
        return ([self.achievement_id] if done else [], list(self.initial_characters) + ([self.unlock_character_id] if done else []))
