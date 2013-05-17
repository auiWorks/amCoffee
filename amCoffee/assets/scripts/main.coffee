window.addEventListener 'load', ->
    amCoffee.init()

amCoffee =
    setting :
        autoComplete_wildMode : false

    init : ->
        me = this

        me.$outputs      = document.getElementById 'outputs'
        me.$promptLine   = document.getElementById 'promptLine'
        me.$prompt       = document.getElementById 'prompt'
        me.$autoComplete = document.getElementById 'autoComplete'

        me.console.init()

        document.body.addEventListener 'click', (e) ->
            me.focusPrompt e

        isOverride = (e) ->
            override   = ([9, 38, 40].indexOf(e.keyCode) isnt -1)
            override ||= ([13].indexOf(e.keyCode) isnt -1 and ! e.shiftKey)
            override ||= ([74, 75, 76, 85].indexOf(e.keyCode) isnt -1 and e.ctrlKey)

        me.$prompt.addEventListener 'keydown', (e) ->
            return unless isOverride e
            e.preventDefault()

            # enter
            if e.keyCode is 13
                me.run()
            # tab
            else if e.keyCode is 9 and e.shiftKey
                me.autoComplete.nav -1
            # tab
            else if e.keyCode is 9 and ! e.shiftKey
                me.autoComplete.nav +1
            # up
            else if e.keyCode is 38
                if me.autoComplete.ing
                    me.autoComplete.nav -1
                else
                    me.history.rewind -1
            # down
            else if e.keyCode is 40
                if me.autoComplete.ing
                    me.autoComplete.nav +1
                else
                    me.history.rewind +1
            # ctrl+k
            else if e.keyCode is 75
                me.history.rewind -1
            # ctrl+j
            else if e.keyCode is 74
                me.history.rewind +1
            # ctrl+l
            else if e.keyCode is 76
                me.clearScreen()
            # ctrl+u
            else if e.keyCode is 85
                me.clearPrompt()

        me.$prompt.addEventListener 'input', me.autoComplete.listener
        me.autoComplete.listener()

        me.$prompt.focus()

        me.history.load()

    focusPrompt : (e) ->
        me = amCoffee

        me.$prompt.focus()

        return if e and e.target is me.$prompt
        return if me.$prompt.innerText.trim() is ''

        # Set cursor to last
        range = document.createRange()
        range.setStart me.$prompt, me.$prompt.childNodes.length
        range.collapse true
        sel = window.getSelection()
        sel.removeAllRanges()
        sel.addRange range

    currentPosition : ->
        me = amCoffee

        source   = me.$prompt.innerText
        position = source.lastIndexOf('\n') + 1

        return position if position is source.length

        range = window.getSelection().getRangeAt 0

        return position + range.endOffset

    autoComplete :
        patterns : []
        context  : ''
        ing      : false

        listener : ->
            parent = amCoffee
            me     = parent.autoComplete

            clearTimeout arguments.callee.timer if arguments.callee.timer?

            arguments.callee.timer = setTimeout ->
                source = parent.$prompt.innerText

                unless parent.currentPosition() is source.length
                    me.hide()
                    return

                unless me.getPatterns source
                    me.list source
            , 100

        getPatterns : (source) ->
            parent = amCoffee
            me     = parent.autoComplete

            source = source.split '\n'
            source = source[source.length - 1]

            matches = source.match /(([a-z_$@0-9]+\.)*)[a-z_$@0-9]*$/i
            context = matches[1]
            if context is ''
                context = 'window'
            else
                context = context.substr 0, context.length - 1

            return false if context is me.context

            me.context = context

            script = """(function () {
                var set = {};
                for (var o = #{context}; o; o = o.__proto__) {
                    try {
                        var names = Object.getOwnPropertyNames(o);
                        for (var i = 0; i < names.length; ++i) set[names[i]] = true;
                    }
                    catch (e) {}
                }
                return Object.keys(set);
            })();"""

            chrome.devtools.inspectedWindow.eval script, (data, isException) ->
                me.patterns = if isException then [] else data
                me.list source

            return true

        list : (source) ->
            parent = amCoffee
            me     = parent.autoComplete

            me.hide()

            source = source.split '\n'
            source = source[source.length - 1]

            return unless me.patterns.length > 0
            return unless matches = source.match /\.?([a-z_$@0-9]*)$/i
            return if matches[0] isnt '.' and matches[1] is ''

            input  = matches[1]

            avaliablePatterns = []

            if parent.setting.autoComplete_wildMode
                regexp = input.replace /(.)/g, "$1.*"
                regexp = "^#{regexp}"
                regexp = new RegExp regexp, 'i'
                for pattern in me.patterns
                    avaliablePatterns.push pattern if regexp.test pattern

            else
                inputLength = input.length
                for pattern in me.patterns
                    avaliablePatterns.push pattern if pattern.substr(0, inputLength) is input

            return if avaliablePatterns.length is 0

            avaliablePatterns.sort()

            for pattern in avaliablePatterns
                $_ = document.createElement 'LI'
                $_.innerHTML = pattern
                parent.$autoComplete.appendChild $_

            me.show()

        show : ->
            parent = amCoffee
            me     = parent.autoComplete

            me.ing = true;
            
            parent.$autoComplete.style.display = 'block'

        hide : ->
            parent = amCoffee
            me     = parent.autoComplete

            me.ing = false;

            parent.$autoComplete.style.display = 'none'
            parent.$autoComplete.innerHTML     = ''

        clean : ->
            parent = amCoffee
            me     = parent.autoComplete

            me.hide()

            me.patterns = []
            me.context  = ''

        nav : (direction) ->
            parent = amCoffee
            me     = parent.autoComplete

            return unless me.ing

            $now = parent.$autoComplete.querySelector('.active')

            if $now
                if direction is -1
                    $to = $now.previousElementSibling
                else
                    $to = $now.nextElementSibling
            else
                if direction is -1
                    $to = parent.$autoComplete.lastChild
                else
                    $to = parent.$autoComplete.firstChild

            if $to
                $now.className = '' if $now
                $to.className = 'active'

                me.fill $to.innerHTML

        fill : (pattern) ->
            parent = amCoffee
            me     = parent.autoComplete

            sourceOriginal = parent.$prompt.innerText

            source = sourceOriginal.split '\n'
            source = source[source.length - 1]
            return unless matches = source.match /\.?([a-z_$@0-9]*)$/i
            return if matches[0] isnt '.' and matches[1] is ''

            parent.$prompt.innerText = (sourceOriginal.substr 0, sourceOriginal.length - matches[1].length) \
                                     + pattern

            parent.focusPrompt()

    console :
        init : ->
            parent = amCoffee
            me     = parent.console

            script = """(function(){
                if (window.__amCoffee_consoleStack) return;
                window.__amCoffee_consoleStack = [];
                ['log', 'warn', 'error', 'dir', 'info'].forEach(function (fn) {
                    var old = console[fn];
                    console[fn] = function () {
                        old && old.apply(console, arguments);
                        for (var i in arguments) {
                            window.__amCoffee_consoleStack.push([fn, arguments[i]]);
                        }
                    };
                });
            })()"""

            chrome.devtools.inspectedWindow.eval script

        retrieve : (callback) ->
            parent = amCoffee
            me     = parent.console

            script = """(function(){
                var ret = window.__amCoffee_consoleStack;
                window.__amCoffee_consoleStack = [];
                return ret;
            })()"""

            chrome.devtools.inspectedWindow.eval script, (datas, isException) ->
                if isException
                    parent.print 'err', datas
                    return

                for data in datas
                    parent.print typeof data[1], data[1]

                callback() if callback

    run : ->
        me = amCoffee

        source = me.$prompt.innerText.trim()

        return unless source isnt ''

        input = me.$prompt.innerHTML
        me.clearPrompt()
        me.history.push input

        $outputPrompt           = document.createElement 'LINE'
        $outputPrompt.className = 'prompt'
        $outputPrompt.innerHTML = input
        me.$outputs.appendChild $outputPrompt

        try
            compiled = me.compile source
            chrome.devtools.inspectedWindow.eval compiled, (data, isException) ->
                me.console.retrieve ->
                    if isException
                        me.print 'err', data
                    else
                        me.print data.type, data.result
        catch err
            me.print 'err', err.message

    compile : (source) ->
        # warp source in a function so it always returns a value
        lines  = source.split '\n'
        source = ' ' + lines.join '\n '
        source = "return (->\n#{source}\n)()"

        compiled = CoffeeScript.compile source
        # process the returned value
        compiled = """(function () {
            var result = #{compiled};
            var type   = typeof result;

            if (typeof result === 'function') {
                result = result.toString();
            }

            return {
                type   : type,
                result : result
            };
        })();"""

    print : (type, result) ->
        me = amCoffee

        $outputResult = document.createElement 'LINE'
        $outputResult.appendChild me.impl type, result

        me.$outputs.appendChild $outputResult

        setTimeout ->
            me.$prompt.focus()

    impl : (type, result) ->
        me = amCoffee

        $output = document.createElement 'ITEM'

        if Array.isArray result
            $output.className = 'array'

            for val in result
                $objectElement           = document.createElement 'ITEM'
                $objectElement.className = 'objectElement'

                $val           = document.createElement 'ITEM'
                $val.className = 'val'
                $val.appendChild me.impl typeof val, val
                $objectElement.appendChild $val

                $output.appendChild $objectElement

        else if type is 'object'
            $output.className = 'object'

            for key, val of result
                $objectElement           = document.createElement 'ITEM'
                $objectElement.className = 'objectElement'

                $key           = document.createElement 'ITEM'
                $key.className = 'key'
                $key.innerHTML = "#{key}:"
                $objectElement.appendChild $key

                $val           = document.createElement 'ITEM'
                $val.className = 'val'
                $val.appendChild me.impl typeof val, val
                $objectElement.appendChild $val

                $output.appendChild $objectElement

        else 
            $output.className = type
            $output.innerText = if type is 'undefined' then 'undefined' else result

        return $output

    clearScreen : ->
        me = amCoffee

        me.$outputs.innerHTML = ''

        me.focusPrompt()

    clearPrompt : ->
        me = amCoffee

        me.$prompt.innerHTML = ''
        me.autoComplete.listener()

    history :
        stack : []
        now   : 0

        push : (source) ->
            me = amCoffee.history

            me.stack.push source unless source is me.stack[me.stack.length - 1]
            me.now = me.stack.length

            me.save()

        rewind : (step) ->
            parent = amCoffee
            me     = parent.history

            source = me.stack[me.now + step]

            return unless source?

            parent.$prompt.innerHTML = source

            parent.focusPrompt()

            parent.autoComplete.clean()

            me.now += step;

        save : ->
            parent = amCoffee
            me     = parent.history

            jsonString = JSON.stringify me.stack

            localStorage.setItem 'stack_' + chrome.devtools.inspectedWindow.tabId, jsonString

        load : ->
            parent = amCoffee
            me     = parent.history

            jsonString = localStorage.getItem 'stack_' + chrome.devtools.inspectedWindow.tabId

            return unless jsonString

            me.stack = JSON.parse jsonString
            me.now   = me.stack.length
