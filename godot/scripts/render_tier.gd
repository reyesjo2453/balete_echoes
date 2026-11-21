class_name RenderTier
## Two looks from one game (docs/HD2D_TECH.md).
##   HIGH  (Forward+: the Linux / Steam Deck build) real depth of field, volumetric fog that turns every lamp and
##         candle into a light shaft, SSAO, stronger bloom.
##   WEB   (Compatibility: the phone / browser review link) none of those exist in this renderer, so the look is
##         faked: the screen-space tilt-shift blur stands in for depth of field (explore_map._post_material), and
##         every lamp gets a soft additive haze sprite instead of fog.
## Headless tests run on the dummy renderer and count as WEB.


## Forward+ (and Mobile, which this project never uses) render through a RenderingDevice; Compatibility, the dummy
## renderer of headless tests, and a desktop that fell back to OpenGL have none.
static func high() -> bool:
	return RenderingServer.get_rendering_device() != null


static func label() -> String:
	return "HIGH (Forward+)" if high() else "WEB (Compatibility)"


## Dresses a map's environment and camera for this tier. Keeps every value the map already set.
static func dress(env: Environment, we: WorldEnvironment, map: Dictionary) -> void:
	if not high():
		return
	env.glow_intensity = 1.05
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(map.get("fog", 0.018))
	env.volumetric_fog_albedo = Color(String(map.get("fog_color", "8a8fa8")))
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.55 # light scatters forward: shafts toward the camera
	env.volumetric_fog_length = 40.0
	var cam := CameraAttributesPractical.new()
	cam.dof_blur_far_enabled = true
	cam.dof_blur_far_distance = 12.0
	cam.dof_blur_far_transition = 6.0
	cam.dof_blur_near_enabled = true
	cam.dof_blur_near_distance = 4.0
	cam.dof_blur_near_transition = 2.5
	cam.dof_blur_amount = 0.045
	we.camera_attributes = cam


## Keeps the plane of focus on what the camera looks at (call every frame).
static func focus(we: WorldEnvironment, cam: Camera3D, look_at: Vector3) -> void:
	if we == null or not (we.camera_attributes is CameraAttributesPractical):
		return
	var a := we.camera_attributes as CameraAttributesPractical
	var d := cam.global_position.distance_to(look_at)
	a.dof_blur_far_distance = d + 4.0
	a.dof_blur_near_distance = maxf(0.6, d - 5.0)
	# Close shots (victory poses, cut-ins) blur much harder per unit of distance: ease the amount down so the
	# background still reads as a place, not a smear. Full strength from 9 m out, a third of it at 3 m.
	a.dof_blur_amount = lerpf(0.015, 0.045, clampf((d - 3.0) / 6.0, 0.0, 1.0))


## A lamp or candle: on HIGH its light also lights the fog; on WEB it gets a soft haze halo (an additive billboard).
static func lamp(light: OmniLight3D, parent: Node, haze: Texture2D) -> void:
	if high():
		light.light_volumetric_fog_energy = 1.6
		return
	if haze == null:
		return
	var s := Sprite3D.new()
	s.texture = haze
	s.pixel_size = clampf(light.omni_range, 1.5, 8.0) * 0.5 / float(haze.get_width())
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.modulate = Color(light.light_color, 0.16)
	s.shaded = false
	s.no_depth_test = false
	s.transparent = true
	s.position = light.position
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = haze
	m.albedo_color = Color(light.light_color, 0.16)
	m.disable_receive_shadows = true
	s.material_override = m
	parent.add_child(s)
	# Ground light pool on wet streets/floors so WEB builds still show rich focal lighting.
	if light.position.y > 0.25 and light.position.y < 4.5:
		var pool := Sprite3D.new()
		pool.texture = haze
		pool.pixel_size = clampf(light.omni_range, 1.8, 7.5) * 0.7 / float(haze.get_width())
		pool.rotation.x = -PI * 0.5
		pool.position = Vector3(light.position.x, 0.016, light.position.z)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.albedo_texture = haze
		pm.albedo_color = Color(light.light_color, clampf(light.light_energy * 0.14, 0.08, 0.24))
		pm.disable_receive_shadows = true
		pool.material_override = pm
		parent.add_child(pool)


## How much the screen-space tilt-shift blurs: less on HIGH, where real depth of field does the work.
static func tilt_blur() -> float:
	return 1.2 if high() else 2.2
