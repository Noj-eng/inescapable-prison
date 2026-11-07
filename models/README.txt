Put Victor's rigged model from Meshy here as:  victor.glb
The 3D test scene (scenes/cellblock_3d.tscn) picks it up automatically and
uses it instead of the stand-in shape. Animations are found by name: any
clip with "idle", "walk"/"run", or "punch"/"attack"/"hit" in its name.

wheel_unit.glb  (the one-wheeled Detention Unit robot guard)
  Rig it in Meshy with the humanoid rig, leg markers on either side of the
  wheel. Save it here as wheel_unit.glb. The game only moves its spine and
  arm bones (for the baton swing) and never plays the leg animations. It
  rolls and leans the whole body in code, spins glowing hubs on the wheel,
  and puts a glowing stun baton in its right hand for you.
