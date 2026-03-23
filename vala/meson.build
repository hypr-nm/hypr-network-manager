gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')
layer_shell_dep = dependency('gtk4-layer-shell-0')

executable(
  'hypr-network-manager',
  [
    'src/models/config.vala',
    'src/ui/main_window.vala',
    'src/app.vala',
    'src/main.vala',
  ],
  dependencies: [gtk_dep, gio_dep, layer_shell_dep],
  install: true
)
