gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')
layer_shell_dep = dependency('gtk4-layer-shell-0')
json_glib_dep = dependency('json-glib-1.0')

executable(
  'hypr-network-manager',
  [
    'src/constants.vala',
    'src/models/config.vala',
    'src/models/wifi_network.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/vpn_connection.vala',
    'src/backend/nm_client.vala',
    'src/ui/blank_window.vala',
    'src/ui/main_window.vala',
    'src/app.vala',
    'src/main.vala',
  ],
  dependencies: [gtk_dep, gio_dep, layer_shell_dep, json_glib_dep],
  install: true
)
