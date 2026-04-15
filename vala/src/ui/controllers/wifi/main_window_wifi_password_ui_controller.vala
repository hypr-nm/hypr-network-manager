public class MainWindowWifiPasswordUIController : Object {
    private NetworkManagerRebuild.UI.Interfaces.IWindowHost host;

    public MainWindowWifiPasswordUIController (NetworkManagerRebuild.UI.Interfaces.IWindowHost host) {
        this.host = host;
    }

    public void set_popup_text_input_mode (bool enabled) {
        host.set_popup_text_input_mode (enabled);
    }
}
