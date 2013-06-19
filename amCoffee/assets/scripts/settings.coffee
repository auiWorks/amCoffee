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

    setting : (key, value) ->
        setting = C.storage('setting') or {}

        if value isnt undefined
            setting[key] = value
            C.storage 'setting', setting

        return setting[key]

    init : ->
        C.$fields = document.getElementsByTagName 'input';

        for $field in C.$fields
            C.recover.call $field
            $field.addEventListener 'change', C.change

    recover : ->
        key = this.getAttribute 'name'

        this.checked = C.setting key

    change : ->
        key   = this.getAttribute 'name'
        value = this.checked

        C.setting key, value
