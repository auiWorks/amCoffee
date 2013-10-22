module.exports = (grunt) ->
    grunt.initConfig
        pkg : grunt.file.readJSON 'package.json'

        copy :
            script :
                expand  : true
                cwd     : 'coffee/'
                src     : [ '**/*.js' ]
                dest    : 'amCoffee/script/'

        coffee :
            dist :
                options :
                    sourceMap : true

                expand  : true
                cwd     : 'coffee/'
                src     : [ '**/*.coffee' ]
                dest    : 'amCoffee/script/'
                ext     : '.js'

        uglify :
            dist :
                expand  : true
                cwd     : 'amCoffee/script/'
                src     : [ '**/*.js', '!**/*.min.js' ]
                dest    : 'amCoffee/script/'

        clean :
            all :
                src : [
                    'amCoffee/script'
                ]

            release :
                src : [
                    'amCoffee/**/*.map'
                ]

        watch :
            copyScript :
                files : [
                    'coffee/**/*.js'
                ]
                tasks : [
                    'copy:script'
                ]

            coffee :
                files : [
                    'coffee/**/*.coffee'
                ]
                tasks : [
                    'coffee'
                    'uglify'
                ]

    grunt.loadNpmTasks name for name in [
        'grunt-contrib-coffee'
        'grunt-contrib-uglify'
        'grunt-contrib-watch'
        'grunt-contrib-clean'
        'grunt-contrib-copy'
    ]

    grunt.registerTask 'default', [
        'clean:all'
        'copy'
        'coffee'
        'uglify'
    ]

    grunt.registerTask 'release', [
        'clean:all'
        'copy'
        'coffee'
        'uglify'
        'clean:release'
    ]
