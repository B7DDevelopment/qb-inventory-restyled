fx_version 'cerulean'
game 'gta5'

description 'qb-inventory'
author 'Vortex Limited'
discord 'https://discord.gg/vxdev'
website 'https://vxdev.shop'
version '1.0'

shared_scripts {
	'@qb-core/shared/locale.lua',
	'locales/en.lua',
	'config.lua',
	'dropitems.lua',
	'@qb-weapons/config.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua',
	'server/decay.lua',
	'server/visual.lua',
}

client_scripts {
	'client/client.lua',
	'client/visual.lua',
}

ui_page {
	'Web/ui.html'
}

escrow_ignore {
		'config.lua',
		'dropitems.lua',
	'server/server.lua',
	'server/decay.lua',
	'server/visual.lua',
	'client/client.lua',
	'client/visual.lua',
		

}

files {
	'Web/ui.html',
	'Web/css/main.css',
	'Web/js/app.js',
	'Web/images/*.svg',
	'Web/images/*.png',
	'Web/images/*.jpg',
	'Web/ammo_images/*.png',
	'Web/attachment_images/*.png',
    'Web/sounds/*.wav',
	'Web/sounds/*.mp3',
	'Web/*.ttf'
}

dependency 'qb-weapons'

lua54 'yes'
