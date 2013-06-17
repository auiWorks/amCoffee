window.addEventListener 'load', ->
    C.init()

C =
    storage : (key, value) ->
        json = localStorage.getItem key
        obj  = JSON.parse json if json

        if value isnt undefined
            obj = value
            localStorage.setItem key, JSON.stringify obj

        return obj

    setting : (key) ->
        setting = C.storage('setting') || {}

        return setting[key]

    init : ->
        C.$outputs      = document.getElementById 'outputs'
        C.$promptLine   = document.getElementById 'promptLine'
        C.$prompt       = document.getElementById 'prompt'
        C.$autoComplete = document.getElementById 'autoComplete'

        C.console.init()

        document.body.addEventListener 'click', (e) ->
            C.focusPrompt e

        isOverride = (e) ->
            override   = ([9, 38, 40].indexOf(e.keyCode) isnt -1)
            override ||= ([13].indexOf(e.keyCode) isnt -1 and ! e.shiftKey)
            override ||= ([74, 75, 76, 85].indexOf(e.keyCode) isnt -1 and e.ctrlKey)

        C.$prompt.addEventListener 'keydown', (e) ->
            return unless isOverride e
            e.preventDefault()

            # enter
            if e.keyCode is 13
                C.run()
            # tab
            else if e.keyCode is 9 and e.shiftKey
                C.autoComplete.nav -1
            # tab
            else if e.keyCode is 9 and ! e.shiftKey
                C.autoComplete.nav +1
            # up
            else if e.keyCode is 38
                if C.autoComplete.ing
                    C.autoComplete.nav -1
                else
                    C.history.rewind -1
            # down
            else if e.keyCode is 40
                if C.autoComplete.ing
                    C.autoComplete.nav +1
                else
                    C.history.rewind +1
            # ctrl+k
            else if e.keyCode is 75
                C.history.rewind -1
            # ctrl+j
            else if e.keyCode is 74
                C.history.rewind +1
            # ctrl+l
            else if e.keyCode is 76
                C.clearScreen()
            # ctrl+u
            else if e.keyCode is 85
                C.clearPrompt()

        C.$prompt.addEventListener 'input', C.autoComplete.listener
        C.autoComplete.listener()

        C.$prompt.focus()

        C.history.load()

        C.tips.init()

    focusPrompt : (e) ->
        C.$prompt.focus()

        return if e and e.target is C.$prompt
        return if C.$prompt.innerText.trim() is ''

        # Set cursor to last
        range = document.createRange()
        range.setStart C.$prompt, C.$prompt.childNodes.length
        range.collapse true
        sel = window.getSelection()
        sel.removeAllRanges()
        sel.addRange range

    currentPosition : ->
        source   = C.$prompt.innerText
        position = source.lastIndexOf('\n') + 1

        return position if position is source.length

        range = window.getSelection().getRangeAt 0

        return position + range.endOffset

    autoComplete :
        patterns : []
        context  : ''
        ing      : false

        listener : ->
            me = C.autoComplete

            clearTimeout arguments.callee.timer if arguments.callee.timer?

            arguments.callee.timer = setTimeout ->
                source = C.$prompt.innerText

                unless C.currentPosition() is source.length
                    me.hide()
                    return

                unless me.getPatterns source
                    me.list source
            , 100

        getPatterns : (source) ->
            me = C.autoComplete

            source = source.split '\n'
            source = source[source.length - 1]

            matches = source.match /(([a-z_$@0-9]+\.)*)[a-z_$@0-9]*$/i
            context = matches[1]
            if context is ''
                if matches = source.match /"(?:[^"\\]|\\.)*"\.[a-z_$@0-9]*$|'(?:[^'\\]|\\.)*'\.[a-z_$@0-9]*$/i
                    context = 'new String("")'
                else
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
            me = C.autoComplete

            me.hide()

            source = source.split '\n'
            source = source[source.length - 1]

            return unless me.patterns.length > 0
            return unless matches = source.match /\.?([a-z_$@0-9]*)$/i
            return if matches[0] isnt '.' and matches[1] is ''

            input  = matches[1]

            avaliablePatterns = []

            if C.setting 'autoComplete_aggressive'
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
                C.$autoComplete.appendChild $_

            me.show()

        show : ->
            me = C.autoComplete

            me.ing = true;
            
            C.$autoComplete.style.display = 'block'

        hide : ->
            me = C.autoComplete

            me.ing = false;

            C.$autoComplete.style.display = 'none'
            C.$autoComplete.innerHTML     = ''

        clean : ->
            me = C.autoComplete

            me.hide()

            me.patterns = []
            me.context  = ''

        nav : (direction) ->
            me = C.autoComplete

            return unless me.ing

            $now = C.$autoComplete.querySelector('.active')

            if $now
                if direction is -1
                    $to = $now.previousElementSibling
                else
                    $to = $now.nextElementSibling
            else
                if direction is -1
                    $to = C.$autoComplete.lastChild
                else
                    $to = C.$autoComplete.firstChild

            unless $to
                if direction is -1
                    $to = C.$autoComplete.lastChild
                else
                    $to = C.$autoComplete.firstChild

            if $to
                $now.className = '' if $now
                $to.className = 'active'

                me.fill $to.innerHTML

        fill : (pattern) ->
            me = C.autoComplete

            sourceOriginal = C.$prompt.innerText

            source = sourceOriginal.split '\n'
            source = source[source.length - 1]
            return unless matches = source.match /\.?([a-z_$@0-9]*)$/i
            return if matches[0] isnt '.' and matches[1] is ''

            C.$prompt.innerText = (sourceOriginal.substr 0, sourceOriginal.length - matches[1].length) \
                                     + pattern

            C.focusPrompt()

    console :
        init : ->
            me = C.console

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
            me = C.console

            script = """(function(){
                var ret = window.__amCoffee_consoleStack;
                window.__amCoffee_consoleStack = [];
                return ret;
            })()"""

            chrome.devtools.inspectedWindow.eval script, (datas, isException) ->
                if isException
                    C.print 'err', datas
                    return

                for data in datas
                    C.print typeof data[1], data[1],
                        printType : data[0]

                callback() if callback

    run : ->
        source = C.$prompt.innerText.trim()

        return unless source isnt ''

        input = C.$prompt.innerHTML
        C.clearPrompt()
        C.history.push input

        $outputPrompt           = document.createElement 'LINE'
        $outputPrompt.className = 'prompt'
        $outputPrompt.innerHTML = input
        C.$outputs.appendChild $outputPrompt

        try
            compiled = C.compile source
            chrome.devtools.inspectedWindow.eval compiled, (data, isException) ->
                C.console.retrieve ->
                    if isException
                        C.print 'err', data
                    else
                        C.print data.type, data.result
        catch err
            C.print 'err', err.message

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

    print : (type, result, options) ->
        $outputResult = document.createElement 'LINE'
        $outputResult.appendChild C.impl type, result

        if options
            $outputResult.className += " #{options.printType}" if options.printType

        C.$outputs.appendChild $outputResult

        setTimeout ->
            C.$prompt.focus()

    impl : (type, result) ->
        $output = document.createElement 'ITEM'

        if Array.isArray result
            $output.className = 'array'

            for val in result
                $objectElement           = document.createElement 'ITEM'
                $objectElement.className = 'objectElement'

                $val           = document.createElement 'ITEM'
                $val.className = 'val'
                $val.appendChild C.impl typeof val, val
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
                $val.appendChild C.impl typeof val, val
                $objectElement.appendChild $val

                $output.appendChild $objectElement

        else 
            $output.className = type
            $output.innerText = if type is 'undefined' then 'undefined' else result

        return $output

    clearScreen : ->
        C.$outputs.innerHTML = ''

        C.focusPrompt()

    clearPrompt : ->
        C.$prompt.innerHTML = ''
        C.autoComplete.listener()

    history :
        stack : []
        now   : 0

        push : (source) ->
            me = C.history

            me.stack.push source unless source is me.stack[me.stack.length - 1]
            me.now = me.stack.length

            me.save()

        rewind : (step) ->
            me = C.history

            source = me.stack[me.now + step]

            return unless source?

            C.$prompt.innerHTML = source

            C.focusPrompt()

            C.autoComplete.clean()

            me.now += step;

        save : ->
            me = C.history

            C.storage 'stack_' + chrome.devtools.inspectedWindow.tabId, me.stack

        load : ->
            me = C.history

            stack = C.storage 'stack_' + chrome.devtools.inspectedWindow.tabId
            return unless stack

            me.stack = stack
            me.now   = me.stack.length

    tips :
        init : ->
            me = C.tips

            $tips = document.getElementsByClassName 'tips'

            tips = C.storage('tips') || {}

            for $tip in $tips
                name = $tip.getAttribute 'name'

                if tips[name]
                    $tip.remove()
                    continue

                $tip.classList.add 'active'
                $tip.addEventListener 'click', me.hide

        hide : ->
            name = this.getAttribute 'name'

            this.remove()

            tips = C.storage('tips') || {}
            tips[name] = true
            C.storage 'tips', tips
