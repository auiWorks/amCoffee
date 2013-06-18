window.addEventListener 'load', ->
    # Google+
    (->
        po       = document.createElement 'script'
        po.type  = 'text/javascript'
        po.async = true
        po.src   = 'https://apis.google.com/js/plusone.js'
        s        = document.getElementsByTagName('script')[0]
        s.parentNode.insertBefore po, s
    )()

    # twitter
    (->
        po       = document.createElement 'script'
        po.type  = 'text/javascript'
        po.async = true
        po.src   = 'https://platform.twitter.com/widgets.js'
        s        = document.getElementsByTagName('script')[0]
        s.parentNode.insertBefore po, s
    )()

    # facebook
    (->
        po               = document.getElementById 'fb-like'
        po.src           = po.getAttribute 'data-src'
        po.removeAttribute 'data-src'
        po.style.display = 'inline-block'
    )()
