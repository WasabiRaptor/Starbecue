require("/scripts/util.lua")
require("/scripts/quest/manager/plugin.lua")

-- Using a plugin for this seems kind of silly, but aside from making another pool, it seems like a decent way to do it
-- Plus, I wanted to try making a quest plugin

SpeciesArticles = subclass(QuestPlugin, "SpeciesArticles")

-- This will run before the player can see any of the quest text, BUT the article parameter needs to be non-nil before this point or the quest generation will fail
function SpeciesArticles:init(...)
  QuestPlugin.init(self, ...)

  if self.config.articleParameter and self.config.speciesParameter then
    local article = self:calculateArticle()
    self.questManager:setQuestParameter(self.questId, self.config.articleParameter, {
      type = "noDetail",
      name = article
    })
  end
end

function SpeciesArticles:calculateArticle()
  local species = (self.questParameters[self.config.speciesParameter] or {}).name
  -- Expecting this to be a string
  if not species or type(species) ~= "string" then return end

  -- If the last character is an S, do "one of the"
  local lastChar = string.sub(species, -1, -1)
  if string.lower(lastChar) == "s" then
    return "one of the"
  end

  --First character is a vowel, do "an"
  local firstChar = string.sub(species, 1, 1)
  local vowels = { a = true, e = true, i = true, o = true, u = true }
  if vowels[string.lower(firstChar)] then
    return "an"
  end
  return "a"
end
