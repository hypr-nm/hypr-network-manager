/* 
 * QR Code generator library (C)
 * 
 * Copyright (c) Project Nayuki. (MIT License)
 * https://www.nayuki.io/page/qr-code-generator-library
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * - The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 * - The Software is provided "as is", without warranty of any kind, express or
 *   implied, including but not limited to the warranties of merchantability,
 *   fitness for a particular purpose and noninfringement. In no event shall the
 *   authors or copyright holders be liable for any claim, damages or other
 *   liability, whether in an action of contract, tort or otherwise, arising from,
 *   out of or in connection with the Software or the use or other dealings in the
 *   Software.
 */

[CCode (cprefix = "qrcodegen_", lower_case_cprefix = "qrcodegen_", cheader_filename = "src/backend/utils/qrcodegen.h")]
namespace QRCodeGen {
    [CCode (cname = "enum qrcodegen_Ecc", cprefix = "qrcodegen_Ecc_")]
    public enum Ecc {
        LOW,
        MEDIUM,
        QUARTILE,
        HIGH
    }

    [CCode (cname = "enum qrcodegen_Mask", cprefix = "qrcodegen_Mask_")]
    public enum Mask {
        AUTO,
        [CCode (cname = "qrcodegen_Mask_0")] MASK_0,
        [CCode (cname = "qrcodegen_Mask_1")] MASK_1,
        [CCode (cname = "qrcodegen_Mask_2")] MASK_2,
        [CCode (cname = "qrcodegen_Mask_3")] MASK_3,
        [CCode (cname = "qrcodegen_Mask_4")] MASK_4,
        [CCode (cname = "qrcodegen_Mask_5")] MASK_5,
        [CCode (cname = "qrcodegen_Mask_6")] MASK_6,
        [CCode (cname = "qrcodegen_Mask_7")] MASK_7
    }

    [CCode (cname = "qrcodegen_BUFFER_LEN_MAX")]
    public const int BUFFER_LEN_MAX;

    [CCode (cname = "qrcodegen_encodeText")]
    public static bool encode_text (string text, [CCode (array_length = false)] uint8[] tempBuffer, [CCode (array_length = false)] uint8[] qrcode, Ecc ecl, int minVersion, int maxVersion, Mask mask, bool boostEcl);

    [CCode (cname = "qrcodegen_getSize")]
    public static int get_size ([CCode (array_length = false)] uint8[] qrcode);

    [CCode (cname = "qrcodegen_getModule")]
    public static bool get_module ([CCode (array_length = false)] uint8[] qrcode, int x, int y);
}
