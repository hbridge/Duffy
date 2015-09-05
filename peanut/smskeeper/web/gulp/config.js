var dest = "../../static/smskeeper/build";
var src = './src';
var srcjs = src + "/js";

module.exports = {
  browserSync: {
    server: {
      // Serve up our build folder
      baseDir: dest
    }
  },
  sass: {
    src: src + "/sass/**/*.{sass,scss}",
    dest: dest,
    settings: {
      indentedSyntax: false, // Enable .sass syntax!
      imagePath: 'images' // Used by the image-url helper
    }
  },
  images: {
    src: src + "/images/**",
    dest: dest + "/images"
  },
  markup: {
    src: src + "/htdocs/**",
    dest: dest
  },
  iconFonts: {
    name: 'Gulp Starter Icons',
    src: src + '/icons/*.svg',
    dest: dest + '/fonts',
    sassDest: src + '/sass',
    template: './gulp/tasks/iconFont/template.sass.swig',
    sassOutputName: '_icons.sass',
    fontPath: 'fonts',
    className: 'icon',
    options: {
      fontName: 'Post-Creator-Icons',
      appendCodepoints: true,
      normalize: false
    }
  },
  browserify: {
    // A separate bundle will be generated for each
    // bundle config in the list below
    bundleConfigs: [{
      entries: srcjs + '/dashboard.jsx',
      dest: dest,
      outputName: 'dashboard_bundle.js',
      // require: ['jquery', 'backbone/node_modules/underscore']
      // See https://github.com/greypants/gulp-starter/issues/87 for note about
      // why this is 'backbone/node_modules/underscore' and not 'underscore'
    }, {
      entries: srcjs + '/history.jsx',
      dest: dest,
      outputName: 'history_bundle.js',
      // list of externally available modules to exclude from the bundle
      // external: ['jquery', 'underscore']
    }, {
      entries: srcjs + '/keeper_app.jsx',
      dest: dest,
      outputName: 'keeper_app_bundle.js',
      // list of externally available modules to exclude from the bundle
      // external: ['jquery', 'underscore']
    }, {
      entries: srcjs + '/review.jsx',
      dest: dest,
      outputName: 'review_bundle.js',
      // list of externally available modules to exclude from the bundle
      // external: ['jquery', 'underscore']
    }, {
      entries: srcjs + '/simulation_dash.jsx',
      dest: dest,
      outputName: 'simulation_dash_bundle.js',
      // list of externally available modules to exclude from the bundle
      // external: ['jquery', 'underscore']
    }]
  },
  production: {
    cssSrc: dest + '/*.css',
    jsSrc: dest + '/*.js',
    dest: dest
  }
};
