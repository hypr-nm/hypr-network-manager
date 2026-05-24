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
