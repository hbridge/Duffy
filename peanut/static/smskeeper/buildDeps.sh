#!/bin/sh

browserify src/keeper_app_requires.js -o build/keeper_app_bundles.js
browserify src/history_requires.js -o build/history_bundle.js