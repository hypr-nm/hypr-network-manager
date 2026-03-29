gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')
layer_shell_dep = dependency('gtk4-layer-shell-0')
json_glib_dep = dependency('json-glib-1.0')

executable(
  'hypr-network-manager',
  [
    'src/logging.vala',
    'src/constants.vala',
    'src/models/config.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_signal_levels.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/vpn_connection.vala',
    'src/backend/nm_client_utils.vala',
    'src/backend/dbus_runner.vala',
    'src/backend/nm_wifi_settings_builder.vala',
    'src/backend/nm_status_formatter.vala',
    'src/backend/nm_ethernet_client.vala',
    'src/backend/nm_wifi_client.vala',
    'src/backend/nm_client.vala',
    'src/backend/nm_vpn_client.vala',
    'src/ui/blank_window.vala',
    'src/ui/controllers/main_window_page_callbacks.vala',
    'src/ui/controllers/main_window_ethernet_controller.vala',
    'src/ui/controllers/main_window_vpn_controller.vala',
    'src/ui/controllers/main_window_wifi_controller.vala',
    'src/ui/controllers/main_window_wifi_details_edit_controller.vala',
    'src/ui/controllers/main_window_wifi_runtime_controller.vala',
    'src/ui/pages/main_window_wifi_page_builder.vala',
    'src/ui/pages/main_window_wifi_row_builder.vala',
    'src/ui/pages/main_window_ethernet_pages_builder.vala',
    'src/ui/pages/main_window_vpn_page_builder.vala',
    'src/ui/pages/main_window_wifi_details_pages_builder.vala',
    'src/ui/utils/main_window_ip_edit_form_builder.vala',
    'src/ui/utils/main_window_helpers.vala',
    'src/ui/utils/main_window_wifi_edit_utils.vala',
    'src/ui/main_window.vala',
    'src/app.vala',
    'src/main.vala',
  ],
  dependencies: [gtk_dep, gio_dep, layer_shell_dep, json_glib_dep],
  install: true
)
