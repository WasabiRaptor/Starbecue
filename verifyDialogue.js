const fs = require('fs');
const {argv} = require('node:process');
const JSONC = require('comment-json');
const { stringify } = require('querystring');

let paths = [
	"./npcs/sbq/dialogue/default.dialogue",
	"./npcs/sbq/dialogue/shy.dialogue",
	"./npcs/sbq/dialogue/flirty.dialogue",
	"./npcs/sbq/LokiVulpix/Auri/npc.dialogue",
	"./npcs/sbq/LokiVulpix/Loki/npc.dialogue",
	"./npcs/sbq/LokiVulpix/Socks/npc.dialogue",
	"./npcs/sbq/LokiVulpix/Clover/npc.dialogue",
	"./npcs/sbq/Zygahedron/Zevi/npc.dialogue",
	"./npcs/sbq/FFWizard/Helena/npc.dialogue",
	"./npcs/sbq/Fevix/Sandy/npc.dialogue",
	"./npcs/sbq/Ferrilata_/Ferri/npc.dialogue",
	"./npcs/sbq/AkariKaen/Akari/npc.dialogue",
	"./npcs/sbq/Blueninja/Blue/npc.dialogue",
]
let uniqueDialogue = {

}
function validate(path, topKey, topFile, topPath) {
	console.log("validating path: '%s' at '%s'", path, topKey)
	let pos = path.search(":")
	let filepath = path.substring(0, pos)
	let key = path.substring(pos + 1)
	if (topFile[key] && (key != topKey)) {
		console.log("found key in top file")
		JSONC.assign(topFile, { [topKey]: ":"+key })
		return
	}
	let value = JSONC.parse(fs.readFileSync("./" + filepath, { encoding: "utf-8" }))[key];
	if (typeof value == "string") {
		if ((value.substring(0, 1) == ":")) {
			let newPath = filepath+value
			JSONC.assign(topFile, { [topKey]: newPath })
			validate(newPath, topKey, topFile)
		} else if (value.substring(0, 1) == "/") {
			JSONC.assign(topFile, { [topKey]: value })
			validate(value, topKey, topFile)
		}
	} else {
		if (typeof value == "undefined") {
			JSONC.assign(topFile, { [topKey]: "Missing: " + topKey + " " + "<dialoguePath>" });
		}
		console.log("validated")
	}
}

for (let [_, path] of paths.entries()) {
	let file = JSONC.parse(fs.readFileSync(path, { encoding: "utf-8" }));
	console.log("reading file: " + path)
	for (let [k, v] of Object.entries(file)) {
		if (typeof v == "string") {
			if ((v.substring(0, 1) == "/") || (v.substring(0, 1) == ":")) continue;
			if (v == "Missing: " + k + " <dialoguePath>") {
				JSONC.assign(file, { [k]: "/npcs/sbq/dialogue/default.dialogue:"+k })
				continue;
			}
			if (v == "Bad Circular Loop") continue;
		}
		let unique = true
		for (let [dialoguePath, value] of Object.entries(uniqueDialogue)) {
			if (JSONC.stringify(v) == JSONC.stringify(value)) {
				JSONC.assign(file, { [k]: dialoguePath })
				unique = false
				break
			}
		}
		if (unique) {
			console.log("found new unique dialogue at:" + k)
			console.log(JSONC.stringify(v))
			uniqueDialogue[path.substring(1)+":"+k] = v
		}
	}
	for (let [k, v] of Object.entries(file)) {
		if (typeof v == "string") {
			if (v.substring(0, 1) == "/") {
				validate(v, k, file)
			}
		}
	}
	for (let [k, v] of Object.entries(file)) {
		if (typeof v == "string") {
			if ((v.substring(0, 1) == ":")) {
				console.log("checking re-point key '%s'", k)
				let value = file[v.substring(1)]
				let keys = {
					[k]: true
				}
				while ((typeof value == "string") && (value.substring(0, 1) == ":")) {
					console.log("checking re-point key '%s'", value.substring(1))
					if (keys[value.substring(1)]) {
						console.log("circular loop found!")
						JSONC.assign(file, { [k]: "/npcs/sbq/dialogue/default.dialogue" + value })
						validate("/npcs/sbq/dialogue/default.dialogue" + value, k, file)
						if (typeof file[k] == "string" && (file[k].substring(0, 1) == ":") && keys[file[k].substring(1)]) {
							JSONC.assign(file, { [k]: "Bad Circular Loop" })
						}
						break;
					}
					keys[value.substring(1)] = true
					JSONC.assign(file, { [k]: value })
					value = file[value.substring(1)]
				}
				console.log("re-point key '%s' validated", k)
			}
		}
	}

	fs.writeFileSync(path, JSONC.stringify(file, null, "\t"), { encoding: "utf-8" });
}
