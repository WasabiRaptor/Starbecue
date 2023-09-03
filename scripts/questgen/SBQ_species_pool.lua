

PoolRelations.sbqSpeciesPool = defineSubclass(Relation, "sbqSpeciesPool") {
	-- Defined in pools.config:
	type = nil,
	poolFile = nil,

	elementType = function (self)
		local result = PoolElementTypes[self.type]
		assert(result ~= nil)
		return result
	  end,

    index = function(self)

		return loadPool(self.poolFile, self:elementType())[1]
	  end,

	query = function (self)
		return self:unpackPredicands {
		  [case(1, self:elementType().matcher)] = function (self, element)
			  if xor(self.negated, #self:index():get(element) > 0) then
				return {{element}}
			  end
			  return Relation.empty
			end,

		  [case(2, Nil)] = function (self)
			  if self.negated then return Relation.some end
			  return self:index():list()
			end,

		  default = Relation.empty
		}
	  end
  }
