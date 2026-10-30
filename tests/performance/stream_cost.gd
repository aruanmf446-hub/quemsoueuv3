extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var Props = load("res://scripts/desert/t15d/city_props.gd")
 var platform := {"kind":"ground","pos":[32,-2.75,0],"size":[64,5.5,4],"pit_left":true,"pit_right":true}
 var sync_peak := 0
 var job_peak := 0
 var same := true
 for sample in range(12):
  var sync = Props.new()
  root.add_child(sync)
  var start := Time.get_ticks_usec()
  sync.build([platform],sample%9+1)
  sync_peak = maxi(sync_peak,Time.get_ticks_usec()-start)
  var queued = Props.new()
  root.add_child(queued)
  for task: Callable in queued.prepare_build([platform],sample%9+1):
   start = Time.get_ticks_usec()
   task.call()
   job_peak = maxi(job_peak,Time.get_ticks_usec()-start)
   await process_frame
  same = same and sync.building_count == queued.building_count and sync.lantern_count == queued.lantern_count
  sync.queue_free()
  queued.queue_free()
  await process_frame
 print("STREAM_PROPS ", JSON.stringify({"synchronous_peak_usec":sync_peak,"queued_task_peak_usec":job_peak,"same_counts":same,"samples":12,"renderer":"headless"}))
 quit(0 if same else 1)
