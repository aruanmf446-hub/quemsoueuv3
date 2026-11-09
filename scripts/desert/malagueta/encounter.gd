extends Node
## Combat orchestration only. Movement, damage, charges and Task input stay in campaign.
signal attack_requested(kind: String)
signal stunned(task: int)
signal task_completed(task: int)
signal reaction_started
signal defeated
signal state_changed

enum State { PHASE_1_GREEN, STUNNED_TASK_1, PHASE_2_RED, STUNNED_TASK_2, PHASE_3_COMBINED, STUNNED_TASK_3, CHEMICAL_REACTION, BOSS_DEFEATED }
@export var stun_seconds := 5.0
@export var damage_to_stun := 4
@export var green_interval := 3.2
@export var red_interval := 2.6
@export var reaction_seconds := 1.2
var state := State.PHASE_1_GREEN
var completed_tasks := 0
var damage := 0
var remaining := 0.0
var green_active := false
var _green_wait := 1.5
var _red_wait := 1.9
var suspended := false

func stage() -> int: return mini(completed_tasks + 1, 3)
func is_stunned() -> bool: return state in [State.STUNNED_TASK_1, State.STUNNED_TASK_2, State.STUNNED_TASK_3]
func fighting() -> bool: return state in [State.PHASE_1_GREEN, State.PHASE_2_RED, State.PHASE_3_COMBINED]
func hit(amount: int) -> bool:
	if not fighting() or suspended or amount <= 0: return false
	damage += amount
	if damage >= damage_to_stun:
		damage = 0
		state = [State.STUNNED_TASK_1, State.STUNNED_TASK_2, State.STUNNED_TASK_3][completed_tasks]
		remaining = stun_seconds
		stunned.emit(stage())
		state_changed.emit()
	return true
func complete_task(task: int) -> bool:
	if suspended or not is_stunned() or remaining <= 0 or task != completed_tasks + 1: return false
	completed_tasks += 1
	task_completed.emit(task)
	if completed_tasks == 3:
		state = State.CHEMICAL_REACTION
		remaining = reaction_seconds
		reaction_started.emit()
	else:
		state = State.PHASE_2_RED if completed_tasks == 1 else State.PHASE_3_COMBINED
		_green_wait = 1.6
		_red_wait = 2.0
	state_changed.emit()
	return true
func tick(delta: float) -> void:
	if suspended or delta <= 0: return
	if is_stunned():
		remaining = maxf(0, remaining - delta)
		if remaining <= 0:
			state = [State.PHASE_1_GREEN, State.PHASE_2_RED, State.PHASE_3_COMBINED][completed_tasks]
			_green_wait = 1.3
			_red_wait = 1.8
			state_changed.emit()
	elif state == State.CHEMICAL_REACTION:
		remaining = maxf(0, remaining - delta)
		if remaining <= 0:
			state = State.BOSS_DEFEATED
			defeated.emit()
			state_changed.emit()
	elif fighting():
		_green_wait -= delta
		_red_wait -= delta
		if stage() != 2 and not green_active and _green_wait <= 0:
			green_active = true
			_green_wait = green_interval
			attack_requested.emit("green")
		if stage() >= 2 and _red_wait <= 0:
			_red_wait = red_interval
			attack_requested.emit("red")
func restore(tasks: int) -> void:
	completed_tasks = clampi(tasks, 0, 3)
	damage = 0
	remaining = 0
	green_active = false
	state = [State.PHASE_1_GREEN, State.PHASE_2_RED, State.PHASE_3_COMBINED, State.CHEMICAL_REACTION][completed_tasks]
	# Saving Task3 happens before its reaction finishes. Resume the reaction, not a dead-end state.
	if completed_tasks==3:remaining=reaction_seconds
	state_changed.emit()
