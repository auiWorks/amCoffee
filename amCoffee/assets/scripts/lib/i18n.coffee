window.addEventListener 'load', ->
    C.init()

C =
    attrNames : []
    selector  : ''
    handlers  :
        content : ($ele, msgName) ->
            $ele.textContent = chrome.i18n.getMessage msgName

        attr : ($ele, attrs) ->
            pairs = attrs.replace(/\s/g, '').split ','

            for pair in pairs
                parts = pair.split ':'

                if parts[0] is '' or parts[1] is null
                    console.error 'i18n: Skiped:', pair
                    continue

                $ele.setAttribute parts[0], chrome.i18n.getMessage parts[1]

    init : ->
        C.attrNames = Object.keys C.handlers
        C.selector  = '[i18n-' + C.attrNames.join('],[i18n-') + ']'

        C.do document

    do : ($root) ->
        $eles = $root.querySelectorAll C.selector

        for $ele in $eles
            for key in C.attrNames
                value = $ele.getAttribute "i18n-#{key}"
                C.handlers[key] $ele, value if value?
