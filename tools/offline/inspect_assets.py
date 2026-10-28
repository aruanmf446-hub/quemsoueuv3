"""Inspeção binária estrutural de FBX/GLB e leitura de OBJ/MTL; nunca converte assets.

Ter ossos/curvas no arquivo não prova que o importador, retarget ou deformação funcionem.
"""
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import struct
from urllib.parse import unquote
import zlib

FBX_MAGIC = b"Kaydara FBX Binary  \x00\x1a\x00"
FBX_TICKS = 46186158000


def _name(value):
    return str(value).split("\x00", 1)[0].split("::")[-1]


class BinaryFBX:
    def __init__(self, data):
        if not data.startswith(FBX_MAGIC):
            raise ValueError("FBX ASCII ou cabeçalho desconhecido: inspeção binária indisponível")
        self.data = data
        self.version = struct.unpack_from("<I", data, 23)[0]
        self.header = 25 if self.version >= 7500 else 13

    def node(self, offset, depth=0):
        if depth > 80 or offset + self.header > len(self.data):
            raise ValueError("Profundidade ou limite de nó FBX inválido")
        fmt = "<QQQB" if self.version >= 7500 else "<IIIB"
        end, count, prop_bytes, name_len = struct.unpack_from(fmt, self.data, offset)
        if end == 0:
            return None, offset + self.header
        start = offset + self.header
        if end > len(self.data) or end <= start or count > 1000000:
            raise ValueError("Intervalo de nó FBX inválido")
        name = self.data[start:start + name_len].decode("utf-8", "replace")
        cursor = start + name_len
        prop_end = cursor + prop_bytes
        if prop_end > end:
            raise ValueError("Propriedades FBX fora do nó")
        properties = []
        for _ in range(count):
            value, cursor = self.property(cursor, name)
            properties.append(value)
        if cursor != prop_end:
            raise ValueError("Tamanho de propriedades FBX inconsistente")
        children = []
        while cursor + self.header <= end:
            child, cursor = self.node(cursor, depth + 1)
            if child is None:
                break
            children.append(child)
        return {"name": name, "properties": properties, "children": children}, end

    def property(self, offset, node_name):
        kind = chr(self.data[offset])
        offset += 1
        scalar = {"Y": "h", "C": "?", "I": "i", "F": "f", "D": "d", "L": "q"}
        if kind in scalar:
            fmt = "<" + scalar[kind]
            return struct.unpack_from(fmt, self.data, offset)[0], offset + struct.calcsize(fmt)
        if kind in "SR":
            size = struct.unpack_from("<I", self.data, offset)[0]
            offset += 4
            end = offset + size
            if end > len(self.data):
                raise ValueError("String FBX truncada")
            return (self.data[offset:end].decode("utf-8", "replace") if kind == "S"
                    else {"raw_bytes": size}), end
        if kind in "fdlibc":
            count, encoding, size = struct.unpack_from("<III", self.data, offset)
            offset += 12
            end = offset + size
            if end > len(self.data) or encoding not in (0, 1):
                raise ValueError("Array FBX inválido")
            item_size = {"f": 4, "d": 8, "l": 8, "i": 4, "b": 1, "c": 1}[kind]
            info = {"array_type": kind, "count": count, "encoding": encoding}
            if node_name in ("PolygonVertexIndex", "KeyTime"):
                expected = count * item_size
                if expected > 64 * 1024 * 1024:
                    raise ValueError("Array de inspeção excede o limite de 64 MiB")
                raw = self.data[offset:end]
                if encoding:
                    decoder = zlib.decompressobj()
                    raw = decoder.decompress(raw, expected + 1)
                    if not decoder.eof or decoder.unconsumed_tail:
                        raise ValueError("Array FBX comprimido excede o tamanho declarado")
                if len(raw) != expected:
                    raise ValueError("Tamanho descomprimido FBX inválido")
                values = struct.iter_unpack("<" + {"i": "i", "l": "q"}.get(kind, "i"), raw)
                if node_name == "PolygonVertexIndex":
                    info["polygon_count"] = sum(v[0] < 0 for v in values)
                else:
                    times = [v[0] for v in values]
                    info["range_seconds"] = [min(times) / FBX_TICKS, max(times) / FBX_TICKS] if times else None
            return info, end
        raise ValueError(f"Tipo de propriedade FBX não suportado: {kind!r}")

    def roots(self):
        offset, result = 27, []
        while offset + self.header < len(self.data):
            node, offset = self.node(offset)
            if node is None:
                break
            result.append(node)
        return result


def walk(nodes):
    for node in nodes:
        yield node
        yield from walk(node["children"])


def inspect_fbx(path):
    reader = BinaryFBX(Path(path).read_bytes())
    roots = reader.roots()
    objects = next((n["children"] for n in roots if n["name"] == "Objects"), [])
    all_nodes = list(walk(roots))
    bones = {n["properties"][0]: _name(n["properties"][1]) for n in objects
             if n["name"] == "Model" and len(n["properties"]) >= 3 and n["properties"][2] == "LimbNode"}
    parents = {}
    for node in all_nodes:
        p = node["properties"]
        if node["name"] == "C" and len(p) >= 3 and p[0] == "OO" and p[1] in bones and p[2] in bones:
            parents[bones[p[1]]] = bones[p[2]]
    topology = sorted((name, parents.get(name)) for name in bones.values())
    texture_nodes = list(walk([n for n in objects if n["name"] in ("Texture", "Video")]))
    textures = sorted({str(n["properties"][0]).replace("\x00", "") for n in texture_nodes
                       if n["name"] in ("RelativeFilename", "FileName", "Filename") and n["properties"]})
    arrays = [(n["name"], n["properties"][0]) for n in all_nodes
              if n["name"] in ("Vertices", "PolygonVertexIndex", "KeyTime") and n["properties"] and isinstance(n["properties"][0], dict)]
    globals_ = {}
    settings = next((n for n in roots if n["name"] == "GlobalSettings"), None)
    if settings:
        for node in walk([settings]):
            p = node["properties"]
            if node["name"] == "P" and len(p) >= 5 and p[0] in ("UpAxis", "UpAxisSign", "FrontAxis", "CoordAxis", "UnitScaleFactor", "OriginalUnitScaleFactor"):
                globals_[p[0]] = p[-1]
    return {
        "format": "FBX binary", "version": reader.version,
        "mesh_count": sum(n["name"] == "Geometry" for n in objects),
        "vertex_count": sum(p["count"] // 3 for name, p in arrays if name == "Vertices"),
        "polygon_count": sum(p.get("polygon_count", 0) for name, p in arrays if name == "PolygonVertexIndex"),
        "skeleton_evidence": {"limb_nodes": len(bones), "bone_names": sorted(bones.values()),
                              "hierarchy_sha256": hashlib.sha256(json.dumps(topology, sort_keys=True).encode()).hexdigest(),
                              "skin_deformers": sum(n["name"] == "Deformer" and n["properties"][-1] == "Skin" for n in objects),
                              "clusters": sum(n["name"] == "Deformer" and n["properties"][-1] == "Cluster" for n in objects)},
        "animation_stacks": [_name(n["properties"][1]) for n in objects if n["name"] == "AnimationStack"],
        "animation_curve_count": sum(n["name"] == "AnimationCurve" for n in objects),
        "key_time_ranges_seconds": sorted({tuple(p["range_seconds"]) for name, p in arrays if name == "KeyTime" and p.get("range_seconds")}),
        "texture_references": textures,
        "embedded_video_bytes": sum(p.get("raw_bytes", 0) for n in all_nodes if n["name"] == "Content" for p in n["properties"] if isinstance(p, dict)),
        "global_settings": globals_,
        "verification_limit": "Estrutura do arquivo; importação, nomes finais dos ossos e retarget não executados.",
    }


def inspect_obj(path):
    vertices = faces = triangles = 0
    materials, used = [], set()
    for line in Path(path).open(encoding="utf-8", errors="replace"):
        parts = line.strip().split()
        if not parts:
            continue
        if parts[0] == "v":
            vertices += 1
        elif parts[0] == "f":
            faces += 1
            triangles += max(0, len(parts) - 3)
        elif parts[0] == "mtllib":
            materials.append(line.strip()[7:].strip())
        elif parts[0] == "usemtl":
            used.add(line.strip()[7:].strip())
    return {"format": "OBJ", "vertex_count": vertices, "polygon_count": faces,
            "triangulated_face_estimate": triangles, "material_libraries": materials,
            "materials_used": sorted(used), "skeleton_evidence": "OBJ não armazena esqueleto, pesos ou animações."}


def inspect_glb(path):
    data = Path(path).read_bytes()
    if len(data) < 20:
        raise ValueError("GLB truncado")
    magic, version, length = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError("Cabeçalho GLB inválido")
    offset, document = 12, None
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        if offset + size > length:
            raise ValueError("Chunk GLB truncado")
        if kind == 0x4E4F534A:
            document = json.loads(data[offset:offset + size].decode("utf-8").rstrip(" \0"))
        offset += size
    if document is None:
        raise ValueError("GLB sem JSON")
    accessors = document.get("accessors", [])
    vertices = indices = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if "POSITION" in primitive.get("attributes", {}):
                vertices += accessors[primitive["attributes"]["POSITION"]]["count"]
            if primitive.get("mode", 4) == 4:
                indices += accessors[primitive["indices"]]["count"] if "indices" in primitive else accessors[primitive["attributes"]["POSITION"]]["count"]
    return {"format": "GLB 2", "mesh_count": len(document.get("meshes", [])),
            "vertex_count": vertices, "triangle_count": indices // 3,
            "skeleton_evidence": {"skins": len(document.get("skins", [])), "joints": sum(len(s.get("joints", [])) for s in document.get("skins", []))},
            "animations": [a.get("name", f"animation_{i}") for i, a in enumerate(document.get("animations", []))],
            "embedded_images": sum("bufferView" in i for i in document.get("images", [])),
            "external_uris": [item["uri"] for group in ("images", "buffers") for item in document.get(group, []) if "uri" in item and not item["uri"].startswith("data:")],
            "extensions_required": document.get("extensionsRequired", []),
            "verification_limit": "Metadados glTF; decodificação de malhas/texturas e reprodução não executadas."}


def inspect_model(path):
    suffix = Path(path).suffix.lower()
    return {".fbx": inspect_fbx, ".obj": inspect_obj, ".glb": inspect_glb}[suffix](path)


def external_reference(path, reference):
    """Preferir o relativo; basename de caminho Windows é apenas candidato, não resolução provada."""
    value = unquote(reference)
    relative = Path(value.replace("\\", "/"))
    absolute = PureWindowsPath(value).is_absolute() or relative.is_absolute()
    target = Path(path).parent / relative
    if not absolute and target.is_file():
        return {"reference": reference, "status": "relative_found", "filename": relative.name}
    basename = PureWindowsPath(value).name
    candidate = Path(path).parent / basename
    return {"reference": reference, "status": "basename_candidate" if candidate.is_file() else "missing",
            "filename": basename, "absolute_authoring_path": absolute}
