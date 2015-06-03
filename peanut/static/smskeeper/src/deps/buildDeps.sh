#!/bin/sh

browserify -g reactify keeper_app_requires.js -o keeper_app_bundle.js
browserify history_requires.js -o history_bundle.js