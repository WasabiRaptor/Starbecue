const fs = require('fs');
const {argv} = require('node:process');
const JSONC = require('comment-json');
const { stringify } = require('querystring');

let dupes = {}

let dialogueTreeFile = fs.readFileSync(argv[2], { encoding: "utf-8" });
let dialogueFile = fs.readFileSync(argv[3], { encoding: "utf-8" });
let secondaryDialoguePath = argv[4]
let secondaryDialogueFile
let secondaryDialogue

if (secondaryDialoguePath) {
	secondaryDialogueFile = fs.readFileSync(secondaryDialoguePath, { encoding: "utf-8" });
	secondaryDialogue = JSONC.parse(secondaryDialogueFile);

	let i = 0
	let npcs = secondaryDialoguePath.search("/npcs")
	if (npcs) {
		i = npcs
	} else {
		let objects = secondaryDialoguePath.search("/objects")
		if (objects) {
			i = objects
		}
	}

	secondaryDialoguePath = secondaryDialoguePath.slice(i, secondaryDialoguePath.length)
}

let dialogueTree = JSONC.parse(dialogueTreeFile);
if (!dialogueTree) {
	console.log("error reading " + argv[2]);
	process.exit(1)
}
let dialogue = JSONC.parse(dialogueFile)
if (!dialogue) {
	console.log("error reading " + argv[3]);
	process.exit(1)
}

let out = handle([], dialogueTree);
checkRepoint(out)
let vanilla = (dialogue?.vanilla ?? {})
JSONC.assign(out, { ["vanilla"]: vanilla })
delete dialogue["vanilla"]
out[Symbol.for("after:vanilla")] = [{
	type: 'LineComment',
	value: ' Unused Dialogue',
	inline: false,
}]
checkRepoint(dialogue)
for (let [key, child] of Object.entries(dialogue)) {
	JSONC.assign(out, {[key]: child})
}
fs.writeFileSync(argv[3], JSONC.stringify(out, null, "\t"), { encoding: "utf-8" });


function handle(path, dialogueTree1) {
	//console.log(path);
	let out = {}
	if (dialogueTree1.dialogueRandom || dialogueTree1.dialogue) {
		JSONC.assign(out, checkDialogue((dialogueTree1.dialogueRandom || dialogueTree1.dialogue)));
	}
	for (let [key, child] of Object.entries(dialogueTree1)) {
		if (key == "next") continue;
		if (typeof child != "object") continue;
		if (Array.isArray(child)) continue;
		JSONC.assign(out, handle([...path, key], child));
	}
	return out;
}

function checkRepoint(input) {
	let checked = {}
	for (let [key, child] of Object.entries(input)) {
		checked[key] = true;
		console.log("checking duplicates! " + key)
		for (let [key2, child2] of Object.entries(input)) {
			if ((key != key2) && !checked[key2] && (JSONC.stringify(child) == JSONC.stringify(child2))) {
				checked[key2] = true;
				if (typeof child == "string") {
					if ((child.substring(0, 1) == ":") | (child.substring(0, 1) == "/")) {
						continue;
					}
				}
				console.log("found duplicates! " + key2)
				JSONC.assign(input, {[key2]:":"+key});
			}
		}
		if (secondaryDialogue){ for (let [key2, child2] of Object.entries(secondaryDialogue)) {
			if (JSONC.stringify(child) == JSONC.stringify(child2)) {
				if (typeof child == "string") {
					if ((child.substring(0, 1) == ":") | (child.substring(0, 1) == "/")) {
						continue;
					}
				}
				JSONC.assign(input, {[key]: secondaryDialoguePath+":"+key2})
				break;
			}
		}}
		if (typeof child == "string") {
			JSONC.assign(input, {[key]:child});
		}
	}
}

function checkDialogue(input) {
	let out = {}
	if (typeof input == "string") {
		if (input.substring(0, 1) == ":") {
			if ((input == ":optionsPrompt") | (input == ":choosePrompt") | (input == ":ynPrompt")) {

			} else {
				let key = input.slice(1, input.length)
				if (!dupes[key]) {
					console.log(key)
					console.log(dialogue[key])
					dupes[key] = true
					if ((typeof dialogue[key] == "undefined") | (dialogue[key] == "Missing: " + key + " " + "<dialoguePath>") | ((dialogue[key] == "/npcs/sbq/dialogue/default.dialogue:"+key) && secondaryDialogue)) {
						delete dialogue[key]
						if (secondaryDialogue && secondaryDialogue[key]) {
							JSONC.assign(out, {[key]: secondaryDialoguePath+":"+key})
						} else JSONC.assign(out, { [key]: "Missing: " + key + " " + "<dialoguePath>" });
					} else {
						let data = dialogue[key]
						delete dialogue[key]
						JSONC.assign(out, checkDialogue(data));
						JSONC.assign(out, { [key]: data })
					}
				}
			}
		}
	}
	if (typeof input == "object") {
		if (Array.isArray(input)) {
			input.forEach(element => {
				JSONC.assign(out, checkDialogue(element));
			});
		} else {
			for (let [key, child] of Object.entries(input)) {
				JSONC.assign(out, checkDialogue(child));
			}
		}
	}
	return out;
}
