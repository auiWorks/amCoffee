chrome.devtools.panels.create \
    chrome.i18n.getMessage('appName'),
    'image/toolbarIcon.png',
    'main.html',
    (panel) ->
        $statusBarButton_Settings = panel.createStatusBarButton \
            'image/icon_settings.svg',
            chrome.i18n.getMessage('settings'),
            false
        $statusBarButton_Settings.onClicked.addListener ->
            window.open 'settings.html'
