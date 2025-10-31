const fs = require('fs');
const {argv} = require('node:process');
const JSONC = require('comment-json');
const { stringify } = require('querystring');
const { execSync } = require('node:child_process');

let paths = [
	["./npcs/sbq/dialogue/default.dialogueTree", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/dialogue/default.dialogueTree", "./npcs/sbq/dialogue/shy.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/dialogue/default.dialogueTree", "./npcs/sbq/dialogue/flirty.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/dialogue/default.dialogueTree", "./npcs/sbq/dialogue/meanbean.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/LokiVulpix/Auri/npc.dialogueTree", "./npcs/sbq/LokiVulpix/Auri/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/LokiVulpix/Loki/npc.dialogueTree", "./npcs/sbq/LokiVulpix/Loki/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/LokiVulpix/Socks/npc.dialogueTree", "./npcs/sbq/LokiVulpix/Socks/npc.dialogue", "./npcs/sbq/dialogue/flirty.dialogue"],
	["./npcs/sbq/LokiVulpix/Clover/npc.dialogueTree", "./npcs/sbq/LokiVulpix/Clover/npc.dialogue", "./npcs/sbq/dialogue/flirty.dialogue"],
	["./objects/sbq/LokiVulpix/Hickory/npc.dialogueTree", "./objects/sbq/LokiVulpix/Hickory/npc.dialogue", "./npcs/sbq/dialogue/flirty.dialogue"],
	["./npcs/sbq/Zygahedron/Zevi/npc.dialogueTree", "./npcs/sbq/Zygahedron/Zevi/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/FFWizard/Helena/npc.dialogueTree", "./npcs/sbq/FFWizard/Helena/npc.dialogue", "./npcs/sbq/dialogue/flirty.dialogue"],
	["./npcs/sbq/Fevix/Sandy/npc.dialogueTree", "./npcs/sbq/Fevix/Sandy/npc.dialogue", "./npcs/sbq/dialogue/flirty.dialogue"],
	["./npcs/sbq/Ferrilata_/Ferri/npc.dialogueTree", "./npcs/sbq/Ferrilata_/Ferri/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/AkariKaen/Akari/npc.dialogueTree", "./npcs/sbq/AkariKaen/Akari/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/Blueninja/Blue/npc.dialogueTree", "./npcs/sbq/Blueninja/Blue/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/DreccanOfPaws/Dreccan/npc.dialogueTree", "./npcs/sbq/DreccanOfPaws/Dreccan/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/MallowGator/Izzy/npc.dialogueTree", "./npcs/sbq/MallowGator/Izzy/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/Razuel/Razuel/npc.dialogueTree", "./npcs/sbq/Razuel/Razuel/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
	["./npcs/sbq/SilentBuizel/Stardust/npc.dialogueTree", "./npcs/sbq/SilentBuizel/Stardust/npc.dialogue", "./npcs/sbq/dialogue/default.dialogue"],
]
let files = {
}

let uniqueDialogue = {

}

function checkUnique(path, k) {
	let file = files[path]
	let v = file[k]
	let stringified = JSONC.stringify(v)
	if (!uniqueDialogue[stringified]) {
		console.log("found new unique dialogue at:" + k)
		console.log(stringified)
		uniqueDialogue[stringified] = path + ":" + k
		return path + ":" + k
	} else {
		return uniqueDialogue[stringified]
	}
}
let checkedPaths = {}
function findUniqueDialogue(path) {
	let file = files[path]
	console.log("finding unique dialogue in: " + path)
	for (let [k, v] of Object.entries(file)) {
		checkedPaths = {}
		if (typeof v == "string") {
			if (v.startsWith(":")) {
				v = verifyRepoint(path, k)
				if (v.startsWith(path))
					JSONC.assign(file, { [k]: v.substring(path.length) })
				else
					JSONC.assign(file, { [k]: v })
				continue
			} else if (v.startsWith("/")) {
				JSONC.assign(file, { [k]: verifyRepoint(path, k) })
				continue
			}
			if (v == "Missing: " + k + " <dialoguePath>") {
				JSONC.assign(file, { [k]: "/npcs/sbq/dialogue/default.dialogue:" + k })
				continue;
			}
			if (v.startsWith("Bad Circular Loop: ")) continue;
		}
		checkUnique(path, k, v)
	}
}

function verifyRepoint(path, k) {
	let file = files[path]
	let v = file[k]
	if (typeof v == "string") {
		console.log(`verifying repoint:\n ${path}:${k}\n ${v}`)
		if ((v.startsWith(":"))) {
			if (checkedPaths[path + v]) {
				return "Bad Circular Loop: " + v
			}
			checkedPaths[path + v] = true
			let key = v.substring(1)
			return verifyRepoint(path, key)
		} else if (v.startsWith("/")) {
			if (checkedPaths[v]) {
				return "Bad Circular Loop: " + v
			}
			checkedPaths[v] = true
			let pos = v.search(":")
			let filepath = v.substring(0, pos)
			let key = v.substring(pos + 1)
			return verifyRepoint(filepath, key)
		}
	}
	return checkUnique(path, k)
}

for (let [_, pathArray] of paths.entries()) {
	let treePath = pathArray[0]
	let dialoguePath = pathArray[1]
	let fallbackPath = pathArray[2]
	let command = 'node "sortDialogue.js" "' + treePath + '" "' + dialoguePath + '"'
	if (fallbackPath) {
		command = 'node "sortDialogue.js" "' + treePath + '" "' + dialoguePath + '" "' + fallbackPath + '"'
	}
	console.log(`Sorting ${dialoguePath}`)
	execSync(command)
}
for (let [_, pathArray] of paths.entries()) {
	let treePath = pathArray[0]
	let dialoguePath = pathArray[1]
	let fallbackPath = pathArray[2]
	if (treePath) {
		files[treePath.substring(1)] = JSONC.parse(fs.readFileSync(treePath, { encoding: "utf-8" }));
	}
	if (dialoguePath){
		files[dialoguePath.substring(1)] = JSONC.parse(fs.readFileSync(dialoguePath, { encoding: "utf-8" }));
	}
	if (fallbackPath){
		files[fallbackPath.substring(1)] = JSONC.parse(fs.readFileSync(fallbackPath, { encoding: "utf-8" }));
	}
}
for (let [_, pathArray] of paths.entries())
	findUniqueDialogue(pathArray[1].substring(1))

for (let [_, pathArray] of paths.entries()) {
	fs.writeFileSync(pathArray[1], JSONC.stringify(files[pathArray[1].substring(1)], null, "\t"), { encoding: "utf-8" });

}
