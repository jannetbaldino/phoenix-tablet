fx_version 'cerulean'
game 'gta5'

lua54 'yes'

description 'PRP Tablet (NUI)'

ui_page 'ui/dist/index.html'

files {
  'ui/index.html',
  'ui/dist/index.html',
  'ui/dist/assets/**',
  'ui/styles.css',
  'ui/app.js',
  'ui/assets/**'
}

shared_scripts {
  '@ox_lib/init.lua',
  '@prp-device-core/shared/config.lua'
}

client_scripts {
  'client/tablet.lua'
}

dependencies {
  'ox_lib',
  'prp-device-core'
}
