project(
  'hypr-network-manager',
  ['vala', 'c'],
  version: '0.2.0',
  default_options: ['warning_level=2']
)

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

subdir('vala')
