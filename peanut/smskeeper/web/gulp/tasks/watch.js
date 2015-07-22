/* Notes:
   - gulp/tasks/browserify.js handles js recompiling with watchify
   - gulp/tasks/browserSync.js watches and reloads compiled files
*/

var gulp     = require('gulp');
var config   = require('../config');
process.env.NODE_ENV = 'development';

gulp.task('watch', ['watchify'], function() {
  gulp.watch(config.sass.src, ['sass']);
  // gulp.watch(config.images.src, ['images']);
  // gulp.watch(config.markup.src, ['markup']);
  // Watchify will watch and recompile our JS, so no need to gulp.watch it
});
