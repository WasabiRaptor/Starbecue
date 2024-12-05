function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  effect.setParentDirectives(config.getParameter("directives"))

  script.setUpdateDelta(0)
end

function update(dt)

end

function uninit()

end
