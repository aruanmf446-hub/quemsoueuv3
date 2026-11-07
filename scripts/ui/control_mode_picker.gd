extends VBoxContainer
## Mesmo seletor nas Configurações e na pausa; salva na preferência real do dispositivo.
const Scheme=preload("res://scripts/desert/t15d/control_scheme.gd")
var preferences: DevicePreferences
var _choice: OptionButton
var _hint: Label
func _ready() -> void:
 name="ControlModePicker"
 add_theme_constant_override("separation",8)
 var line:=HBoxContainer.new()
 line.add_theme_constant_override("separation",16)
 add_child(line)
 var title:=PlayerUI.label(tr("Modo de controle"),PlayerUI.CONTROL_FONT)
 title.autowrap_mode=TextServer.AUTOWRAP_OFF
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 title.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 line.add_child(title)
 _choice=OptionButton.new()
 _choice.name="ControlMode"
 _choice.custom_minimum_size=Vector2(300,56)
 _choice.add_theme_font_size_override("font_size",PlayerUI.CONTROL_FONT)
 PlayerUI.style_button(_choice,false)
 for label: String in Scheme.LABELS:_choice.add_item(tr(label))
 _choice.select(Scheme.MODES.find(str(preferences.values.control_mode)))
 line.add_child(_choice)
 _hint=PlayerUI.label(tr(Scheme.description()),18,PlayerUI.MUTED)
 _hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 add_child(_hint)
 _choice.item_selected.connect(_selected)
func _selected(index: int) -> void:
 if preferences.set_preference("control_mode",Scheme.MODES[index]):
  _hint.text=tr(Scheme.description())
  _hint.modulate=Color.WHITE
 else:
  _choice.select(Scheme.MODES.find(str(preferences.values.control_mode)))
  _hint.text=tr("Não foi possível salvar a preferência neste dispositivo.")
  _hint.modulate=Color("#f3b4a2")
