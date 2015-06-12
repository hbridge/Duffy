var gulp = require('gulp');


// set NODE_ENV so we use prod REACT
process.env.NODE_ENV = 'production';
gulp.task('production', function(){
	gulp.start(['uglifyJs']);
});

// Run this to compress all the things!
// gulp.task('production', ['karma'], function(){
//   // This runs only if the karma tests pass
//   gulp.start(['markup', 'images', 'iconFont', 'minifyCss', 'uglifyJs'])
// });
