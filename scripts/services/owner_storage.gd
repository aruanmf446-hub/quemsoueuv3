class_name OwnerStorage
extends RefCounted
## Pastas locais por dono neste aparelho: "guest" para o visitante, senão o id da conta GAME.
## Nada aqui é sincronizado; sincronização remota é contrato do backend (docs/contracts).
const ROOT := "user://players"


static func owner_id() -> String:
	var services := PlayerServices.current
	if services == null or services.session == null or not services.session.authenticated(): return ""
	return safe(str(services.session.user.get("id", "")))


## Ids GAME são UUID; qualquer outra coisa vira hash para nunca formar um caminho arbitrário.
static func safe(user_id: String) -> String:
	var id := user_id.strip_edges()
	if id.is_empty(): return ""
	if RegEx.create_from_string("^[0-9a-fA-F-]{36}$").search(id) != null: return id.to_lower()
	return id.sha256_text()


static func folder(owner: String) -> String:
	return ROOT + "/" + ("guest" if owner.is_empty() else owner)


static func path(owner: String, relative: String) -> String:
	var target := folder(owner) + "/" + relative
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	return target
