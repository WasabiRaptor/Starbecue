const fs = require('fs');
const {argv} = require('node:process');
const JSONC = require('comment-json');
const { stringify } = require('querystring');

let paths = [
	"./humanoid/any/voreOccupant.animation",
	"./humanoid/any/voreOccupantQuadruped.animation",
	"./humanoid/sbq/slime/voreOccupant.animation",
	"./humanoid/sbq/vaporeonGiant/voreOccupant.animation",
	"./humanoid/sbq/Xeronious/Kaiju/voreOccupant.animation",
	"./humanoid/sbq/LakotaAmitola/ziellekDragon/voreOccupant.animation",
	"./humanoid/sbq/IcyVixen/Fray/voreOccupant.animation",
	"./humanoid/sbq/LokiVulpix/Auri/voreOccupant.animation"
]

function isObject(item) {
  return (item && typeof item === 'object' && !Array.isArray(item));
}

function mergeDeep(target, ...sources) {
  if (!sources.length) return target;
  const source = sources.shift();

  if (isObject(target) && isObject(source)) {
    for (const key in source) {
      if (isObject(source[key])) {
        if (!target[key]) Object.assign(target, { [key]: {} });
        mergeDeep(target[key], source[key]);
      } else {
        Object.assign(target, { [key]: source[key] });
      }
    }
  }

  return mergeDeep(target, ...sources);
}

for (let [_, path] of paths.entries()) {
	console.log("setting up occupants for: " + path)

	let fileString = fs.readFileSync(path, { encoding: "utf-8" });
	let original = JSONC.parse(fileString)
	let occupantSlots = original.occupantSlots || 16

	let output = {};
	for (let i = 0; i < (occupantSlots); i++) {
		let occupantSlot = fileString.replaceAll("<occupant>", "occupant" + i);
		mergeDeep(output, JSONC.parse(occupantSlot));
	}
	let newPath = path.replace("Occupant", "Occupants")
	fs.writeFileSync(newPath, JSONC.stringify(output, null, "\t"), { encoding: "utf-8" });
	console.log("output file: " + newPath)
}
