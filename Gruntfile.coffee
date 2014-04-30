module.exports = (grunt) ->
    require('load-grunt-tasks')(grunt)

    grunt.initConfig
        pkg : grunt.file.readJSON 'package.json'

        path :
            src  : 'src'
            dist : 'dist'

        clean :
            dist :
                dot : true
                src : [
                    '<%= path.dist %>'
                ]

        copy :
            static :
                expand  : true
                cwd     : '<%= path.src %>'
                dest    : '<%= path.dist %>'
                src     : [
                    'manifest.json'
                    '*.html'
                    '{_locales,image,css,js}/**/*.*'
                ]

        imagemin :
            options :
                pngquant : true

            dist :
                expand : true
                cwd    : '<%= path.src %>/image'
                dest   : '<%= path.dist %>/image'
                src    : [ '**/*.{png,jpg,gif}' ]

        coffee :
            dist :
                expand  : true
                cwd     : '<%= path.src %>/coffee'
                dest    : '<%= path.dist %>/js'
                src     : [ '**/*.coffee' ]
                ext     : '.js'
                extDot  : 'last'

        concurrent :
            dist : [
                'copy:static'
                'coffee'
            ]

        uglify :
            dist :
                files : [{
                    expand  : true
                    cwd     : '<%= path.dist %>/js'
                    dest    : '<%= path.dist %>/js'
                    src     : [ '**/*.js' ]
                    ext     : '.js'
                    extDot  : 'last'
                }]

        cssmin :
            dist :
                files : [{
                    expand  : true
                    cwd     : '<%= path.dist %>/css'
                    dest    : '<%= path.dist %>/css'
                    src     : [ '**/*.css' ]
                    ext     : '.css'
                    extDot  : 'last'
                }]

        watch :
            copyStatic :
                files : [
                    '<%= path.src %>/manifest.json'
                    '<%= path.src %>/*.html'
                    '<%= path.src %>/{_locales,image,css,js}/**/*.*'
                ]
                tasks : [ 'copy:static' ]

            coffee :
                files : [ '<%= path.src %>/coffee/**/*.coffee' ]
                tasks : [ 'coffee' ]

    grunt.registerTask 'default', [
        'clean:dist'
        'concurrent:dist'
    ]

    grunt.registerTask 'release', [
        'clean:dist'
        'concurrent:dist'
        'imagemin'
        'uglify'
        'cssmin'
    ]
