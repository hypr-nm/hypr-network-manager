gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')
layer_shell_dep = dependency('gtk4-layer-shell-0')
json_glib_dep = dependency('json-glib-1.0')
libnm_dep = dependency('libnm', version: '>= 1.0')
libnl_dep = dependency('libnl-3.0')
libnl_genl_dep = dependency('libnl-genl-3.0')
libsecret_dep = dependency('libsecret-1')
gnome = import('gnome')

conf_data = configuration_data()
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('CREATE_AP_PATH', get_option('prefix') / get_option('libexecdir') / 'hypr-network-manager' / 'hypr-create-ap')
conf_data.set_quoted('CREATE_AP_DEV_PATH', meson.project_source_root() / 'scripts' / 'hypr-create-ap' / 'hypr-create-ap')

config_file = configure_file(
  input: 'src/config.vala.in',
  output: 'config.vala',
  configuration: conf_data
)

app_resources = gnome.compile_resources(
  'hypr_network_manager_resources',
  'resources/hypr-network-manager.gresource.xml',
  source_dir: 'resources',
  c_name: 'hypr_network_manager_resources'
)

add_project_arguments(
  '-DGETTEXT_PACKAGE="' + meson.project_name() + '"',
  language: 'c'
)

nl80211_client_lib = static_library(
  'nl80211-client',
  'src/backend/utils/nl80211_client.c',
  dependencies: [libnl_dep, libnl_genl_dep],
  install: false,
)

executable(
  'hypr-network-manager',
  [
    config_file,
    app_resources,
    'src/logging.vala',
    'src/constants.vala',
    'src/models/config.vala',
    'src/models/hotspot_config.vala',
    'src/models/wireguard_peer.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_saved_profile.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_security_capabilities.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/network_data.vala',
    'src/models/vpn_connection.vala',
    'src/models/window_config_context.vala',
    'src/models/network_state_context.vala',
    'src/ui/interfaces/window_host.vala',
    'src/ui/interfaces/widget_factory.vala',
    'src/ui/interfaces/vpn_form_fields.vala',
    'src/ui/utils/main_window_dismiss_handler.vala',
    'src/ui/utils/main_window_layer_shell_configurator.vala',
    'src/ui/utils/transient_surface_tracker.vala',
    'src/ui/widgets/dynamic_string_list.vala',
    'src/ui/widgets/dynamic_peer_list.vala',
    'src/ui/widgets/tracked_drop_down.vala',
    'src/ui/widgets/tracked_popover.vala',
    'src/ui/widgets/qr_code_widget.vala',
    'src/ui/widgets/main_window_tabs_menu.vala',
    'src/ui/views/status_bar_view.vala',
    'src/ui/views/app_content_navigation_manager.vala',
    'src/ui/views/wifi_section_view.vala',
    'src/ui/views/hotspot_section_view.vala',
    'src/ui/views/saved_profiles_view.vala',
    'src/ui/views/ethernet_section_view.vala',
    'src/ui/views/vpn_section_view.vala',
    'src/backend/utils/nm_ip_config_helper.vala',
    'src/backend/utils/nm_wifi_utils.vala',
    'src/backend/utils/nm_hotspot_utils.vala',
    'src/backend/hotspot_config_storage.vala',
    'src/backend/utils/qrcodegen.c',
    'src/backend/utils/qrcodegen.vapi',
    'src/backend/utils/nl80211_client.vapi',
    'src/backend/network_manager_ports.vala',
    'src/backend/mappers/vpn_mapper.vala',
    'src/backend/mappers/device_mapper.vala',
    'src/backend/mappers/wifi_security_mapper.vala',
    'src/ui/formatters/network_device_formatter.vala',
    'src/ui/formatters/wifi_signal_levels.vala',
    'src/backend/nm_status_formatter.vala',
    'src/backend/nm_ethernet_client.vala',
    'src/backend/services/secrets_service.vala',
    'src/backend/services/nl80211_ap_monitor.vala',
    'src/backend/services/hotspot_service.vala',
    'src/backend/services/wifi_scanner_service.vala',
    'src/backend/services/saved_profile_service.vala',
    'src/backend/nm_client.vala',
    'src/backend/nm_vpn_client.vala',
    'src/ui/blank_window.vala',
    'src/ui/interfaces/main_window_ip_edit_page.vala',
    'src/ui/interfaces/main_window_network_details_page.vala',
    'src/ui/interfaces/main_window_wifi_row_action_handler.vala',
    'src/ui/interfaces/main_window_ethernet_row_action_handler.vala',
    'src/ui/interfaces/main_window_wifi_page_action_handler.vala',
    'src/ui/interfaces/main_window_wifi_row_provider.vala',
    'src/ui/controllers/ethernet/main_window_ethernet_connection_controller.vala',
    'src/ui/controllers/ethernet/main_window_ethernet_controller.vala',
    'src/ui/controllers/vpn/main_window_vpn_controller.vala',
    'src/ui/controllers/hotspot/main_window_hotspot_controller.vala',
    'src/ui/controllers/wifi/main_window_wifi_controller.vala',
    'src/ui/controllers/main_window_refresh_coordinator.vala',
    'src/ui/controllers/main_window_flight_mode_controller.vala',
    'src/ui/controllers/wifi/main_window_wifi_details_edit_controller.vala',
    'src/ui/controllers/wifi/main_window_wifi_connection_controller.vala',
    'src/ui/controllers/profiles/main_window_profiles_controller.vala',
    'src/ui/views/main_window_wifi_row_reconciler.vala',
    'src/ui/pages/wifi/main_window_wifi_page_builder.vala',
    'src/ui/pages/wifi/main_window_wifi_details_page.vala',
    'src/ui/pages/wifi/main_window_wifi_edit_page.vala',
    'src/ui/pages/wifi/main_window_wifi_share_page.vala',
    'src/ui/pages/wifi/main_window_wifi_row_builder.vala',
    'src/ui/pages/ethernet/main_window_ethernet_details_page.vala',
    'src/ui/pages/ethernet/main_window_ethernet_edit_page.vala',
    'src/ui/pages/ethernet/main_window_ethernet_page_builder.vala',
    'src/ui/pages/ethernet/main_window_ethernet_row_builder.vala',
    'src/ui/pages/vpn/main_window_vpn_page_builder.vala',
    'src/ui/pages/vpn/main_window_vpn_details_page.vala',
    'src/ui/pages/vpn/main_window_vpn_edit_page.vala',
    'src/ui/pages/vpn/main_window_vpn_peer_edit_page.vala',
    'src/ui/pages/vpn/main_window_vpn_add_page.vala',
    'src/ui/pages/vpn/main_window_vpn_setup_page.vala',
    'src/ui/pages/profiles/main_window_profiles_page.vala',
    'src/ui/pages/profiles/main_window_profiles_details_page.vala',
    'src/ui/pages/profiles/main_window_wifi_saved_edit_page.vala',
    'src/ui/utils/main_window_ip_sensitivity_rules.vala',
    'src/ui/utils/main_window_ip_validation.vala',
    'src/ui/utils/main_window_ip_config_helper.vala',
    'src/ui/utils/main_window_password_prompt_manager.vala',
    'src/ui/utils/main_window_css_classes.vala',
    'src/ui/utils/main_window_ip_details_row_builder.vala',
    'src/ui/utils/main_window_ip_edit_form_builder.vala',
    'src/ui/utils/main_window_vpn_form_builder.vala',
    'src/ui/utils/main_window_ui_metrics.vala',
    'src/ui/utils/main_window_icon_resources.vala',
    'src/ui/utils/main_window_helpers.vala',
    'src/ui/utils/main_window_helpers_formatting.vala',
    'src/ui/utils/main_window_wifi_edit_utils.vala',
    'src/ui/utils/main_window_vpn_request_builder.vala',
    'src/ui/utils/wifi_qr_builder.vala',
    'src/ui/widgets/main_window_refresh_progress_bar.vala',
    'src/ui/main_window.vala',
    'src/app.vala',
    'src/main.vala',
  ],
  c_args: ['-w'],
  dependencies: [gtk_dep, gio_dep, layer_shell_dep, json_glib_dep, libnm_dep, libsecret_dep],
  link_with: nl80211_client_lib,
  install: true
)

nl80211_client_test = executable(
  'test-nl80211-client',
  'tests/test_nl80211_client.c',
  link_with: nl80211_client_lib,
  dependencies: [libnl_dep, libnl_genl_dep],
  override_options: ['b_ndebug=false'],
  install: false,
)

test('nl80211-client', nl80211_client_test)

nm_hotspot_profile_test = executable(
  'test-nm-hotspot-profile',
  [
    'tests/test_nm_hotspot_profile.vala',
    'src/constants.vala',
    'src/backend/utils/nm_hotspot_utils.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep, libnm_dep],
  override_options: ['b_ndebug=false'],
  install: false,
)

test('nm-hotspot-profile', nm_hotspot_profile_test)

nm_boundary_mappers_test = executable(
  'test-nm-boundary-mappers',
  [
    'tests/test_nm_boundary_mappers.vala',
    'src/constants.vala',
    'src/models/network_device.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_saved_profile.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_security_capabilities.vala',
    'src/models/network_state_context.vala',
    'src/backend/utils/nm_wifi_utils.vala',
    'src/backend/mappers/device_mapper.vala',
    'src/backend/mappers/wifi_security_mapper.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep, libnm_dep],
  override_options: ['b_ndebug=false'],
  install: false,
)

test('nm-boundary-mappers', nm_boundary_mappers_test)

test(
  'create-ap-script',
  find_program('bash'),
  args: [
    files('tests/test_create_ap_script.sh'),
    meson.project_source_root() / 'scripts' / 'hypr-create-ap' / 'hypr-create-ap',
  ],
)

hotspot_config_storage_test = executable(
  'test-hotspot-config-storage',
  [
    'tests/test_hotspot_config_storage.vala',
    'src/logging.vala',
    'src/constants.vala',
    'src/models/hotspot_config.vala',
    'src/backend/hotspot_config_storage.vala',
  ],
  c_args: ['-w'],
  vala_args: ['--define=HOTSPOT_STORAGE_TESTS'],
  dependencies: [gio_dep, json_glib_dep, libsecret_dep],
  override_options: ['b_ndebug=false'],
  install: false,
)

test('hotspot-config-storage', hotspot_config_storage_test)

vpn_roundtrip_test = executable(
  'test-vpn-roundtrip',
  [
    'tests/test_vpn_roundtrip.vala',
    'src/constants.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/wireguard_peer.vala',
    'src/models/vpn_connection.vala',
    'src/backend/mappers/vpn_mapper.vala',
    'src/backend/utils/nm_ip_config_helper.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep, libnm_dep],
)
test('VPN roundtrip', vpn_roundtrip_test)

config_parser_test = executable(
  'test-config-parser',
  [
    'tests/test_config_parser.vala',
    'src/constants.vala',
    'src/logging.vala',
    'src/models/config.vala',
    'src/ui/utils/main_window_ui_metrics.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep, json_glib_dep],
)
test(
  'config parser',
  config_parser_test,
  args: [
    meson.project_source_root() / 'dotfiles' / 'hypr-network-manager' / 'config.json',
  ],
)

hotspot_controller_test = executable(
  'test-hotspot-controller',
  [
    'tests/test_hotspot_controller.vala',
    'src/constants.vala',
    'src/models/hotspot_config.vala',
    'src/models/wireguard_peer.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_saved_profile.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_security_capabilities.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/network_data.vala',
    'src/models/vpn_connection.vala',
    'src/backend/network_manager_ports.vala',
    'src/ui/controllers/hotspot/main_window_hotspot_controller.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep],
  override_options: ['b_ndebug=false'],
)
test('hotspot controller', hotspot_controller_test)

refresh_coordinator_test = executable(
  'test-refresh-coordinator',
  [
    'tests/test_refresh_coordinator.vala',
    'src/logging.vala',
    'src/constants.vala',
    'src/models/hotspot_config.vala',
    'src/models/wireguard_peer.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_saved_profile.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_security_capabilities.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/network_data.vala',
    'src/models/vpn_connection.vala',
    'src/backend/network_manager_ports.vala',
    'src/ui/interfaces/window_host.vala',
    'src/ui/controllers/main_window_refresh_coordinator.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep],
  override_options: ['b_ndebug=false'],
)
test('refresh coordinator', refresh_coordinator_test)

wifi_details_controller_test = executable(
  'test-wifi-details-controller',
  [
    'tests/test_wifi_details_controller.vala',
    'src/constants.vala',
    'src/models/hotspot_config.vala',
    'src/models/wireguard_peer.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_saved_profile.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_security_capabilities.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/network_data.vala',
    'src/models/vpn_connection.vala',
    'src/models/network_state_context.vala',
    'src/backend/network_manager_ports.vala',
    'src/ui/interfaces/window_host.vala',
    'src/ui/controllers/wifi/main_window_wifi_details_edit_controller.vala',
  ],
  c_args: ['-w'],
  dependencies: [gio_dep],
  override_options: ['b_ndebug=false'],
)
test('wifi details controller', wifi_details_controller_test)
