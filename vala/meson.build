gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')
layer_shell_dep = dependency('gtk4-layer-shell-0')
json_glib_dep = dependency('json-glib-1.0')
libnm_dep = dependency('libnm', version: '>= 1.0')
gnome = import('gnome')

app_resources = gnome.compile_resources(
  'hypr_network_manager_resources',
  'resources/hypr-network-manager.gresource.xml',
  source_dir: 'resources',
  c_name: 'hypr_network_manager_resources'
)

add_project_arguments(
  '-w',
  language: 'c'
)

executable(
  'hypr-network-manager',
  [
    app_resources,
    'src/logging.vala',
    'src/constants.vala',
    'src/models/config.vala',
    'src/models/wifi_network.vala',
    'src/models/wifi_saved_profile.vala',
    'src/models/wifi_security_mode.vala',
    'src/models/wifi_signal_levels.vala',
    'src/models/network_update_requests.vala',
    'src/models/network_ip_settings.vala',
    'src/models/network_device.vala',
    'src/models/vpn_connection.vala',
    'src/models/window_config_context.vala',
    'src/models/network_state_context.vala',
    'src/ui/interfaces/window_host.vala',
    'src/ui/views/status_bar_view.vala',
    'src/ui/views/app_content_navigation_manager.vala',
    'src/ui/views/wifi_section_view.vala',
    'src/ui/views/saved_profiles_view.vala',
    'src/ui/views/ethernet_section_view.vala',
    'src/ui/views/vpn_section_view.vala',
    'src/backend/utils/nm_ip_config_helper.vala',
    'src/backend/utils/nm_wifi_utils.vala',
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
    'src/ui/controllers/main_window_refresh_coordinator.vala',
    'src/ui/controllers/main_window_wifi_details_edit_controller.vala',
    'src/ui/controllers/main_window_wifi_row_action_callbacks.vala',
    'src/ui/controllers/main_window_wifi_runtime_controller.vala',
    'src/ui/controllers/main_window_wifi_row_reconciler.vala',
    'src/ui/controllers/main_window_wifi_saved_profile_form_utils.vala',
    'src/ui/controllers/main_window_profile_adapter.vala',
    'src/ui/pages/main_window_wifi_page_builder.vala',
    'src/ui/pages/main_window_wifi_row_builder.vala',
    'src/ui/pages/main_window_ethernet_pages_builder.vala',
    'src/ui/pages/main_window_vpn_page_builder.vala',
    'src/ui/pages/main_window_wifi_details_pages_builder.vala',
    'src/ui/pages/main_window_profiles_pages_builder.vala',
    'src/ui/utils/main_window_ip_sensitivity_rules.vala',
    'src/ui/utils/main_window_ip_edit_form_builder.vala',
    'src/ui/utils/main_window_ui_metrics.vala',
    'src/ui/utils/main_window_css_class_resolver.vala',
    'src/ui/utils/main_window_icon_resources.vala',
    'src/ui/utils/main_window_helpers.vala',
    'src/ui/utils/main_window_helpers_formatting.vala',
    'src/ui/utils/main_window_wifi_edit_utils.vala',
    'src/ui/main_window.vala',
    'src/app.vala',
    'src/main.vala',
  ],
  dependencies: [gtk_dep, gio_dep, layer_shell_dep, json_glib_dep, libnm_dep],
  install: true
)
