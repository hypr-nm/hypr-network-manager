using Gtk;

public class MainWindowWifiRowActionCallbacks : Object {
    public MainWindowWifiNetworkCallback on_open_details;
    public MainWindowWifiNetworkCallback on_forget_saved_network;
    public MainWindowWifiNetworkCallback on_disconnect;
    public MainWindowWifiNetworkPasswordCallback on_connect;
    public MainWindowWifiNetworkBoolCallback on_set_auto_connect;
    public MainWindowPasswordPromptShowCallback on_show_password_prompt;
    public MainWindowPasswordPromptHideCallback on_hide_password_prompt;

    public MainWindowWifiRowActionCallbacks (
        owned MainWindowWifiNetworkCallback on_open_details,
        owned MainWindowWifiNetworkCallback on_forget_saved_network,
        owned MainWindowWifiNetworkCallback on_disconnect,
        owned MainWindowWifiNetworkPasswordCallback on_connect,
        owned MainWindowWifiNetworkBoolCallback on_set_auto_connect,
        owned MainWindowPasswordPromptShowCallback on_show_password_prompt,
        owned MainWindowPasswordPromptHideCallback on_hide_password_prompt
    ) {
        this.on_open_details = (owned) on_open_details;
        this.on_forget_saved_network = (owned) on_forget_saved_network;
        this.on_disconnect = (owned) on_disconnect;
        this.on_connect = (owned) on_connect;
        this.on_set_auto_connect = (owned) on_set_auto_connect;
        this.on_show_password_prompt = (owned) on_show_password_prompt;
        this.on_hide_password_prompt = (owned) on_hide_password_prompt;
    }
}
