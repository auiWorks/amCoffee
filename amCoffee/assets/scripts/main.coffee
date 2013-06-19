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

        chrome.devtools.network.onNavigated.addListener C.inject
        C.inject()

        document.body.addEventListener 'click', (e) ->
            C.focusPrompt e

        isOverride = (e) ->
            override   = ([9, 38, 40].indexOf(e.keyCode) isnt -1)
            override ||= ([13].indexOf(e.keyCode) isnt -1 and ! e.shiftKey)
            override ||= ([74, 75, 76, 82, 85].indexOf(e.keyCode) isnt -1 and e.ctrlKey)

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
            # ctrl+r
            else if e.keyCode is 82
                chrome.devtools.inspectedWindow.reload()
            # ctrl+u
            else if e.keyCode is 85
                C.clearPrompt()

        C.$prompt.addEventListener 'input', C.autoComplete.listener
        C.autoComplete.listener()

        C.focusPrompt()

        C.history.load()

        C.tips.init()

    # inject amCoffee object into inspected window
    inject : ->
        chrome.devtools.inspectedWindow.eval """
            if (window.__amCoffee__) return;
            window.__amCoffee__ = {
                process : #{C.process.toString()}
            };
        """, C.console.init

    focusPrompt : (e) ->
        C.$prompt.focus()

        return if e and e.target is C.$prompt

        C.$prompt.scrollIntoView()

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

            script = ->
                return if window.__amCoffee__.consoleStack
                window.__amCoffee__.consoleStack = []
                ['log', 'warn', 'error', 'dir', 'info'].forEach (fn) ->
                    old = console[fn]
                    console[fn] = ->
                        old.apply console, arguments if old
                        for argument in arguments
                            window.__amCoffee__.consoleStack.push [fn, argument]
                        return

            chrome.devtools.inspectedWindow.eval "(#{script.toString()})()"

        retrieve : (callback) ->
            me = C.console

            script = ->
                consoleStack = window.__amCoffee__.consoleStack
                window.__amCoffee__.consoleStack = []
                ret = []
                ret.push [item[0], window.__amCoffee__.process item[1]] for item in consoleStack
                return ret

            chrome.devtools.inspectedWindow.eval "(#{script.toString()})()", (datas, isException) ->
                if isException
                    C.print
                        type  : 'err'
                        value : isException.value
                    return

                for data in datas
                    C.print data[1],
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
                        C.print
                            type  : 'err'
                            value : isException.value
                    else
                        C.print data
        catch err
            C.print
                type  : 'err'
                value : err.message

    compile : (source) ->
        # warp source in a function so it always returns a value
        lines  = source.split '\n'
        source = ' ' + lines.join '\n '
        source = "return (->\n#{source}\n)()"

        compiled = CoffeeScript.compile source

        compiled = """(function(){
            var value = #{compiled};
            return window.__amCoffee__.process(value);
        })();"""

    # process the returned value in inspected window's context
    process : (value) ->
        type = typeof value;

        # is function
        if type is 'function'
            value = value.toString()

        # is node
        else if value && value.nodeType
            if value.nodeType is Node.ELEMENT_NODE
                type  = 'tag'
                attrs = value.attributes
                value =
                    tagName    : value.tagName.toLowerCase()
                    attributes : {}
                value.attributes[attr.name] = attr.value for attr in attrs

            else
                type  = 'node'
                value = value.nodeName.toLowerCase()

        # is array
        else if Array.isArray value
            type  = 'array'
            ret   = []
            ret.push arguments.callee _value for _value in value
            value = ret

        # is object
        else if type is 'object'
            ret      = {}
            ret[key] = arguments.callee _value for key, _value of value
            value    = ret

        return {
            type  : type
            value : value
        }

    print : (result, options) ->
        $outputResult = document.createElement 'LINE'
        $outputResult.appendChild C.impl result

        if options
            $outputResult.className += " #{options.printType}" if options.printType

        C.$outputs.appendChild $outputResult

        setTimeout ->
            C.focusPrompt()

    impl : (result) ->
        $output = document.createElement 'ITEM'

        if result.type is 'array'
            $output.className = 'array'

            for _value in result.value
                $objectElement           = document.createElement 'ITEM'
                $objectElement.className = 'objectElement'

                $val           = document.createElement 'ITEM'
                $val.className = 'val'
                $val.appendChild C.impl _value
                $objectElement.appendChild $val

                $output.appendChild $objectElement

        else if result.type is 'object'
            $output.className = 'object'

            for key, _value of result.value
                $objectElement           = document.createElement 'ITEM'
                $objectElement.className = 'objectElement'

                $key           = document.createElement 'ITEM'
                $key.className = 'key'
                $key.innerHTML = "#{key}:"
                $objectElement.appendChild $key

                $val           = document.createElement 'ITEM'
                $val.className = 'val'
                $val.appendChild C.impl _value
                $objectElement.appendChild $val

                $output.appendChild $objectElement

        else if result.type is 'tag'
            $openTag           = document.createElement 'ITEM'
            $openTag.className = 'tag'

            $tagName           = document.createElement 'ITEM'
            $tagName.className = 'tag-name'
            $tagName.innerHTML = result.value.tagName
            $openTag.appendChild $tagName

            for name, _value of result.value.attributes
                $attribute           = document.createElement 'ITEM'
                $attribute.className = 'tag-attribute'

                $attributeName           = document.createElement 'ITEM'
                $attributeName.className = 'tag-attribute-name'
                $attributeName.innerHTML = name
                $attribute.appendChild $attributeName

                unless _value is ''
                    $attributeValue           = document.createElement 'ITEM'
                    $attributeValue.className = 'tag-attribute-value'
                    $attributeValue.innerHTML = _value
                    $attribute.appendChild $attributeValue

                $openTag.appendChild $attribute

            $bogus           = document.createElement 'ITEM'
            $bogus.innerHTML = '…'

            $closeTag           = document.createElement 'ITEM'
            $closeTag.className = 'tag'

            $tagNameClose           = $tagName.cloneNode()
            $tagNameClose.innerText = "/#{result.value.tagName}"
            $closeTag.appendChild $tagNameClose

            $output.appendChild $openTag
            $output.appendChild $bogus
            $output.appendChild $closeTag

        else 
            $output.className = result.type
            $output.innerText = if result.type is 'undefined' then 'undefined' else result.value

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
