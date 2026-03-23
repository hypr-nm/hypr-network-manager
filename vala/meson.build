gtk_dep = dependency('gtk4')
gio_dep = dependency('gio-2.0')

executable(
  'hypr-network-manager',
  [
    'src/app.vala',
    'src/main.vala',
  ],
  dependencies: [gtk_dep, gio_dep],
  install: true
)
