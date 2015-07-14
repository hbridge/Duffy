var gulp    = require('gulp');
var config  = require('../config').production;
var size    = require('gulp-filesize');
var uglify = require('gulp-uglify');
var gutil = require('gulp-util');
var ignore = require('gulp-ignore');

gulp.task('uglifyJs', ['browserify'], function() {
  return gulp.src(config.jsSrc)
    .pipe(ignore.exclude([ "**/*.map" ]))
    .pipe(uglify().on('error', gutil.log))
    .pipe(gulp.dest(config.dest))
    .pipe(size());
});
