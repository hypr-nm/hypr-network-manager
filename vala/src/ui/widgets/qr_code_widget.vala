/*
 * Copyright (C) 2026 hypr-network-manager Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Constants;
using Gtk;
using Gdk;

public class HyprNetworkManager.UI.Widgets.QrCodeWidget : Gtk.DrawingArea {
    private uint8[]? qrcode_data = null;
    private int qr_size = 0;
    
    private bool _is_loading = false;
    private uint tick_cb_id = 0;
    private double animation_time = 0.0;
    
    public bool is_loading {
        get { return _is_loading; }
        set {
            if (_is_loading != value) {
                _is_loading = value;
                if (_is_loading) {
                    animation_time = 0.0;
                    if (tick_cb_id == 0) {
                        tick_cb_id = this.add_tick_callback ((widget, clock) => {
                            animation_time += 0.02;
                            this.queue_draw ();
                            return true;
                        });
                    }
                } else {
                    if (tick_cb_id != 0) {
                        this.remove_tick_callback (tick_cb_id);
                        tick_cb_id = 0;
                    }
                    this.queue_draw ();
                }
            }
        }
    }

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

    private bool is_finder_pattern (int x, int y, int size) {
        if (x < 8 && y < 8) return true;
        if (x > size - 9 && y < 8) return true;
        if (x < 8 && y > size - 9) return true;
        return false;
    }

    private void on_draw (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        if (qrcode_data == null || qr_size == 0) return;

        // Draw white background
        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.rectangle (0, 0, width, height);
        cr.fill ();

        // Calculate scaling
        double margin = 0.0;
        double usable_width = width - 2 * margin;
        double usable_height = height - 2 * margin;
        
        double scale_x = usable_width / qr_size;
        double scale_y = usable_height / qr_size;
        double scale = double.min (scale_x, scale_y);

        double offset_x = (width - (qr_size * scale)) / 2.0;
        double offset_y = (height - (qr_size * scale)) / 2.0;

        cr.set_source_rgb (0.0, 0.0, 0.0);
        
        if (_is_loading) {
            cr.select_font_face ("monospace", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            cr.set_font_size (scale * 1.2);
            string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

            for (int y = 0; y < qr_size; y++) {
                for (int x = 0; x < qr_size; x++) {
                    if (is_finder_pattern (x, y, qr_size)) {
                        if (QRCodeGen.get_module (qrcode_data, x, y)) {
                            cr.set_source_rgb (0.0, 0.0, 0.0);
                            cr.rectangle (offset_x + x * scale, offset_y + y * scale, scale, scale);
                            cr.fill ();
                        }
                    } else {
                        double speed = 2.0 + ((x * 17) % 5);
                        double offset = (x * 31) % 100;
                        
                        double head_y = (animation_time * speed + offset);
                        double wrap_height = qr_size + 15.0;
                        head_y = head_y - ((int)(head_y / wrap_height)) * wrap_height;
                        
                        int trail_length = 8 + ((x * 7) % 8);
                        double dist_to_head = head_y - y;
                        
                        if (dist_to_head >= 0 && dist_to_head < trail_length) {
                            double alpha = 1.0 - (dist_to_head / trail_length);
                            if (alpha > 0.8) alpha = 1.0;
                            else if (alpha > 0.4) alpha = 0.5;
                            else alpha = 0.2;
                            
                            cr.set_source_rgba (0.0, 0.0, 0.0, alpha);
                            
                            int char_idx = (x * 13 + y * 17 + (int)(animation_time * 2)) % chars.length;
                            string c = chars.substring (char_idx, 1);
                            
                            Cairo.TextExtents extents;
                            cr.text_extents (c, out extents);
                            
                            cr.move_to (offset_x + x * scale + (scale - extents.width)/2.0 - extents.x_bearing,
                                        offset_y + y * scale + (scale - extents.height)/2.0 - extents.y_bearing);
                            cr.show_text (c);
                        }
                    }
                }
            }
        } else {
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
}
