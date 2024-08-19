const fs = require('fs');
const {argv} = require('node:process');
const JSONC = require('comment-json');
const { stringify } = require('querystring');

let paths = [
	"./npcs/sbq/dialogue/default.dialogue",
	"./npcs/sbq/dialogue/shy.dialogue",
	"./npcs/sbq/dialogue/flirty.dialogue",
	"./npcs/sbq/dialogue/meanbean.dialogue",
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

for (let [_, path] of paths.entries()) {
	let file = JSONC.parse(fs.readFileSync(path, { encoding: "utf-8" }));
	console.log("reading file: " + path)
	for (let [k, v] of Object.entries(file)) {
		if (typeof v == "string") {
			if (v.substring(0, 1) == "/") {
				let pos = v.search(":")
				let filepath = v.substring(0, pos)
				let key = v.substring(pos + 1)
				let value = JSONC.parse(fs.readFileSync("./" + filepath, { encoding: "utf-8" }))[key];
				JSONC.assign(file, { [k]: value})
			} else if ((v.substring(0, 1) == ":")) {
				JSONC.assign(file, { [k]: file[v.substring(1)] })
			}
		}
	}

	fs.writeFileSync(path, JSONC.stringify(file, null, "\t"), { encoding: "utf-8" });
}
