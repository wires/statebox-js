var gulp = require('gulp');
var $ = require('gulp-load-plugins')();

// convert our markdown to html
var pygmentize = require('pygmentize-bundled');
gulp.task('markdown', function () {

    var markdownOptions = {
        highlight: function (code, lang, callback) {
            var options = {
                lang: lang || 'coffeescript',
                format: 'html',
                options: {
                    nowrap: true
                }
            };
            pygmentize(options, code, function (err, result) {
                if(result)
                    callback(err, result.toString());
                else
                    callback(err, code);
            });
        }
    };

    return gulp.src('*.litcoffee')
        .pipe($.extReplace('.md'))
        .pipe($.marked(markdownOptions))
        .pipe($.header('<html><head><link rel="stylesheet" href="css/fruity.css"></head><body>'))
        .pipe($.footer('</body></html>'))
        .pipe(gulp.dest('build/'))
        .pipe($.size());
});

gulp.task('css', function(){
    return gulp.src('css/*.css')
        .pipe(gulp.dest('build/css'));
});

//gulp.task('watch', ['site'], function(){
//	gulp.watch('*.md', ['site']);
//});

gulp.task('default', [], function () {
	gulp.start('markdown');
    gulp.start('css');
});
