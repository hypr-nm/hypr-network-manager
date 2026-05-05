using Gtk;

namespace HyprNetworkManager.UI.Interfaces {

public interface IVpnFormFields : GLib.Object {
    public abstract Gtk.Entry? gateway_entry { get; set; }
    public abstract Gtk.Entry? user_entry { get; set; }
    public abstract Gtk.Entry? password_entry { get; set; }
    
    // WireGuard
    public abstract Gtk.Entry? wg_private_key_entry { get; set; }
    public abstract Gtk.Entry? wg_peer_public_key_entry { get; set; }
    public abstract Gtk.Entry? wg_peer_endpoint_entry { get; set; }
    public abstract Gtk.Entry? wg_peer_allowed_ips_entry { get; set; }
    public abstract Gtk.Entry? wg_preshared_key_entry { get; set; }
    public abstract Gtk.Entry? wg_listen_port_entry { get; set; }
    public abstract Gtk.Entry? wg_fwmark_entry { get; set; }
    public abstract Gtk.Switch? wg_peer_routes_switch { get; set; }

    // OpenVPN
    public abstract Gtk.Entry? ovpn_remote_entry { get; set; }
    public abstract Gtk.Entry? ovpn_port_entry { get; set; }
    public abstract HyprNetworkManager.UI.Widgets.TrackedDropDown? ovpn_proto_dropdown { get; set; }
    public abstract Gtk.Entry? ovpn_user_entry { get; set; }
    public abstract Gtk.Entry? ovpn_password_entry { get; set; }
    public abstract Gtk.Entry? ovpn_ca_cert_entry { get; set; }
    public abstract Gtk.Entry? ovpn_client_cert_entry { get; set; }
    public abstract Gtk.Entry? ovpn_private_key_entry { get; set; }
    public abstract Gtk.Entry? ovpn_tls_auth_key_entry { get; set; }
    public abstract Gtk.Entry? ovpn_cipher_entry { get; set; }
    public abstract Gtk.Entry? ovpn_auth_entry { get; set; }
}

}
