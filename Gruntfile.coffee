module.exports = (grunt) ->
    require('load-grunt-tasks')(grunt)

    grunt.initConfig
        pkg : grunt.file.readJSON 'package.json'

        path :
            src  : 'src'
            dist : 'dist'

        exec :
            install :
                cmd : 'bourbon install --path=<%= path.src %>/sass'

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
                    '{_locales,image,font,css,js}/**/*.*'
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

        sass :
            dist :
                options :
                    unixNewlines : true

                expand  : true
                cwd     : '<%= path.src %>/sass'
                dest    : '<%= path.dist %>/css'
                src     : [ '**/*.sass', '!**/_*.sass' ]
                ext     : '.css'
                extDot  : 'last'

        concurrent :
            dist : [
                'copy:static'
                'coffee'
                'sass'
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
                    '<%= path.src %>/{_locales,image,font,css,js}/**/*.*'
                ]
                tasks : [ 'copy:static' ]

            coffee :
                files : [ '<%= path.src %>/coffee/**/*.coffee' ]
                tasks : [ 'coffee' ]

            sass :
                files : [ '<%= path.src %>/sass/**/*.sass' ]
                tasks : [ 'sass' ]

    grunt.registerTask 'default', [
        'exec:install'
        'clean:dist'
        'concurrent:dist'
    ]

    grunt.registerTask 'release', [
        'exec:install'
        'clean:dist'
        'concurrent:dist'
        'imagemin'
        'uglify'
        'cssmin'
    ]
