const fs = require('fs');
const {argv} = require('node:process');
const JSONC = require('comment-json');
const { stringify } = require('querystring');

let baseColors = {}

for (let v of fs.readdirSync("./species", { recursive: true })) {
	if (v.endsWith(".species.patch")) {

	} else if (v.endsWith(".species")) {
	}
}
