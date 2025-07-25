fx_version 'cerulean'
game 'gta5'
lua54 'yes'

version '2.3.4'

shared_scripts {
    'shared/locales/shared.lua',
    'shared/locales/*.lua'
}

client_scripts {
    'code/client.lua'
}

server_scripts {
    'code/server.lua',
    '@mysql-async/lib/MySQL.lua'
}

ui_page 'files/ui/index.html'

files {
    'files/ui/index.html',
    'files/ui/style.css',
    'files/sound/notification.mp3',
    'files/ui/script.js'
}
