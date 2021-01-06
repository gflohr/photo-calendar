const path = require('path');

module.exports = {
	entry: './_assets/index.js',
	mode: 'production',
	output: {
		path: path.resolve(__dirname, 'assets'),
		filename: 'name.js',
	}
};