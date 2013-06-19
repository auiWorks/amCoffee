chrome.devtools.panels.create \
    chrome.i18n.getMessage('appName'),
    'assets/images/toolbarIcon.png',
    'main.html',
    (panel) ->
        $statusBarButton_Settings = panel.createStatusBarButton \
            'assets/images/icon_settings.svg',
            chrome.i18n.getMessage('settings'),
            false
        $statusBarButton_Settings.onClicked.addListener ->
            window.open 'settings.html'
