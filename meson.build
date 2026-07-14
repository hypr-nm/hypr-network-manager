project(
  'hypr-network-manager',
  ['vala', 'c'],
  version: '0.2.0',
  default_options: ['warning_level=2']
)

i18n = import('i18n')

buildtype = get_option('buildtype')
is_release_like = buildtype == 'release' or buildtype == 'debugoptimized'

if is_release_like
  add_project_arguments(
    '-D_FORTIFY_SOURCE=3',
    '-fstack-protector-strong',
    '-Wformat',
    '-Wformat-security',
    language: ['c']
  )
endif

if host_machine.system() == 'linux'
  add_project_link_arguments(
    '-Wl,-z,relro',
    '-Wl,-z,now',
    '-Wl,-z,noexecstack',
    language: ['c']
  )
endif

create_ap_dir = get_option('libexecdir') / 'hypr-network-manager'
install_data(
  'scripts/create_ap/create_ap',
  install_dir: create_ap_dir,
  install_mode: 'rwxr-xr-x',
)

polkit_actions_dir = get_option('datadir') / 'polkit-1' / 'actions'
polkit_rules_dir = get_option('datadir') / 'polkit-1' / 'rules.d'

conf_data_polkit = configuration_data()
conf_data_polkit.set('CREATE_AP_PATH', get_option('prefix') / get_option('libexecdir') / 'hypr-network-manager' / 'create_ap')
conf_data_polkit.set('CREATE_AP_DEV_PATH', meson.current_source_dir() / 'scripts' / 'create_ap' / 'create_ap')

install_data(
  'packaging/polkit/20-hypr-network-manager-create-ap.rules',
  install_dir: polkit_rules_dir,
  install_mode: 'rw-r--r--',
)

configure_file(
  input: 'packaging/polkit/org.hypr-network-manager.create-ap.policy.in',
  output: 'org.hypr-network-manager.create-ap.policy',
  configuration: conf_data_polkit,
  install: get_option('install-polkit'),
  install_dir: polkit_actions_dir,
)

is_dev_build = buildtype != 'release'
configure_file(
  input: 'packaging/polkit/org.hypr-network-manager.create-ap.dev.policy.in',
  output: 'org.hypr-network-manager.create-ap.dev.policy',
  configuration: conf_data_polkit,
  install: get_option('install-polkit') and is_dev_build,
  install_dir: polkit_actions_dir,
)

subdir('vala')
subdir('po')
