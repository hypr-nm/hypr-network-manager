public delegate void MainWindowActionCallback ();
public delegate void MainWindowBoolCallback (bool value);
public delegate void MainWindowRefreshActionCallback (bool request_wifi_scan);
public delegate void MainWindowErrorCallback (string message);
public delegate void MainWindowLogCallback (string message);
public delegate void MainWindowWifiNetworkCallback (WifiNetwork net);
public delegate void MainWindowWifiNetworkBoolCallback (WifiNetwork net, bool value);
public delegate void MainWindowWifiNetworkPasswordCallback (WifiNetwork net, string? password);
public delegate Gtk.ListBoxRow MainWindowWifiRowBuildCallback (WifiNetwork net);
public delegate void MainWindowPasswordPromptShowCallback (Gtk.Revealer revealer, Gtk.Entry entry);
public delegate void MainWindowPasswordPromptHideCallback (
    Gtk.Revealer revealer,
    Gtk.Entry entry,
    string? value
);
