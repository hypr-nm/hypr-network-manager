using Gtk;

public interface IMainWindowIpEditPage : Object {
    public abstract Gtk.DropDown ipv4_method_dropdown { get; set; }
    public abstract Gtk.Entry ipv4_address_entry { get; set; }
    public abstract Gtk.Entry ipv4_prefix_entry { get; set; }
    public abstract Gtk.Entry ipv4_gateway_entry { get; set; }
    public abstract Gtk.Switch dns_auto_switch { get; set; }
    public abstract Gtk.Entry ipv4_dns_entry { get; set; }
    public abstract Gtk.DropDown ipv6_method_dropdown { get; set; }
    public abstract Gtk.Entry ipv6_address_entry { get; set; }
    public abstract Gtk.Entry ipv6_prefix_entry { get; set; }
    public abstract Gtk.Entry ipv6_gateway_entry { get; set; }
    public abstract Gtk.Switch ipv6_dns_auto_switch { get; set; }
    public abstract Gtk.Entry ipv6_dns_entry { get; set; }
}
