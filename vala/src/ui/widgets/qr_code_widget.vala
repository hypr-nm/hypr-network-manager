using Gtk;
using Gdk;

public class HyprNetworkManager.UI.Widgets.QrCodeWidget : Gtk.DrawingArea {
    private uint8[]? qrcode_data = null;
    private int qr_size = 0;

    public QrCodeWidget (string text) {
        set_size_request (150, 150);
        generate_qr (text);
        set_draw_func (on_draw);
    }

    private void generate_qr (string text) {
        uint8[] tempBuffer = new uint8[QRCodeGen.BUFFER_LEN_MAX];
        uint8[] qrcode = new uint8[QRCodeGen.BUFFER_LEN_MAX];
        
        bool success = QRCodeGen.encode_text (
            text, 
            tempBuffer, 
            qrcode, 
            QRCodeGen.Ecc.LOW, 
            1, 40, QRCodeGen.Mask.AUTO, true
        );
        
        if (success) {
            this.qrcode_data = qrcode;
            this.qr_size = QRCodeGen.get_size (qrcode);
        } else {
            this.qrcode_data = null;
            this.qr_size = 0;
        }
    }

    private void on_draw (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        if (qrcode_data == null || qr_size == 0) return;

        // Draw white background
        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.rectangle (0, 0, width, height);
        cr.fill ();

        // Calculate scaling
        double margin = 10.0;
        double usable_width = width - 2 * margin;
        double usable_height = height - 2 * margin;
        
        double scale_x = usable_width / qr_size;
        double scale_y = usable_height / qr_size;
        double scale = double.min (scale_x, scale_y);

        double offset_x = (width - (qr_size * scale)) / 2.0;
        double offset_y = (height - (qr_size * scale)) / 2.0;

        cr.set_source_rgb (0.0, 0.0, 0.0);
        for (int y = 0; y < qr_size; y++) {
            for (int x = 0; x < qr_size; x++) {
                if (QRCodeGen.get_module (qrcode_data, x, y)) {
                    cr.rectangle (offset_x + x * scale, offset_y + y * scale, scale, scale);
                    cr.fill ();
                }
            }
        }
    }
}
