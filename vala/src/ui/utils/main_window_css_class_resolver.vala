using GLib;
using Gtk;

namespace MainWindowCssClassResolver {
    private HashTable<string, bool>? indexed_classes = null;
    private string? indexed_base_css_path = null;
    private Regex? import_regex = null;
    private Regex? block_comment_regex = null;
    private Regex? selector_header_regex = null;
    private Regex? selector_class_regex = null;

    public static void initialize (string base_css_path) {
        if (base_css_path.strip () == "") {
            return;
        }

        if (indexed_classes != null && indexed_base_css_path == base_css_path) {
            return;
        }

        var class_set = new HashTable<string, bool> (str_hash, str_equal);
        var visited_files = new HashTable<string, bool> (str_hash, str_equal);
        index_css_file (to_absolute_path (base_css_path), class_set, visited_files);

        indexed_classes = class_set;
        indexed_base_css_path = base_css_path;
    }

    public static void add_best_class (Gtk.Widget widget, string[] class_hierarchy) {
        string selected_class = resolve_best_class (class_hierarchy);
        if (selected_class == "") {
            return;
        }
        widget.add_css_class (selected_class);
    }

    public static string resolve_best_class (string[] class_hierarchy) {
        if (class_hierarchy.length == 0) {
            return "";
        }

        string fallback_class = resolve_fallback_class (class_hierarchy);

        // If theme indexing is unavailable, fall back to the most generic class.
        if (indexed_classes == null || indexed_classes.size () == 0) {
            return fallback_class;
        }

        string best_class = "";
        int best_score = int.MIN;

        for (int i = 0; i < class_hierarchy.length; i++) {
            string candidate = class_hierarchy[i].strip ();
            if (candidate == "" || !indexed_classes.contains (candidate)) {
                continue;
            }

            int score = score_candidate (candidate, i, class_hierarchy.length);
            if (best_class == "" || score > best_score || (score == best_score && candidate < best_class)) {
                best_class = candidate;
                best_score = score;
            }
        }

        if (best_class != "") {
            return best_class;
        }

        return fallback_class;
    }

    private static int score_candidate (string css_class, int hierarchy_index, int hierarchy_length) {
        // Earlier hierarchy entries win strongly, then more specific class names.
        int hierarchy_score = (hierarchy_length - hierarchy_index) * 1000000;

        int segment_count = 1;
        for (int i = 0; i < css_class.length; i++) {
            if (css_class[i] == '-') {
                segment_count++;
            }
        }

        int specificity_score = segment_count * 1000 + (int) css_class.length;
        return hierarchy_score + specificity_score;
    }

    private static string resolve_fallback_class (string[] class_hierarchy) {
        for (int i = class_hierarchy.length - 1; i >= 0; i--) {
            string candidate = class_hierarchy[i].strip ();
            if (candidate != "") {
                return candidate;
            }
        }

        return "";
    }

    private static void index_css_file (
        string css_path,
        HashTable<string, bool> class_set,
        HashTable<string, bool> visited_files
    ) {
        string normalized_path = css_path.strip ();
        if (normalized_path == "" || visited_files.contains (normalized_path)) {
            return;
        }
        visited_files.insert (normalized_path, true);

        if (!FileUtils.test (normalized_path, FileTest.EXISTS)) {
            return;
        }

        string content;
        size_t content_length = 0;
        try {
            FileUtils.get_contents (normalized_path, out content, out content_length);
        } catch (Error e) {
            return;
        }

        string content_without_comments = strip_css_comments (content);

        index_imported_files (normalized_path, content_without_comments, class_set, visited_files);
        index_classes (content_without_comments, class_set);
    }

    private static void index_imported_files (
        string importer_css_path,
        string content,
        HashTable<string, bool> class_set,
        HashTable<string, bool> visited_files
    ) {
        if (!ensure_regexes_initialized () || import_regex == null) {
            return;
        }

        try {
            MatchInfo match_info;
            if (!import_regex.match (content, 0, out match_info)) {
                return;
            }

            do {
                string import_target = match_info.fetch (1);
                string? import_path = resolve_import_path (importer_css_path, import_target);
                if (import_path != null) {
                    index_css_file (import_path, class_set, visited_files);
                }
            } while (match_info.next ());
        } catch (RegexError e) {
            return;
        }
    }

    private static void index_classes (string content, HashTable<string, bool> class_set) {
        if (!ensure_regexes_initialized () || selector_header_regex == null || selector_class_regex == null) {
            return;
        }

        try {
            MatchInfo selector_match_info;
            if (!selector_header_regex.match (content, 0, out selector_match_info)) {
                return;
            }

            do {
                // Inspect each selector header (`... {`) so chains like `.btn.primary`
                // are indexed as both `btn` and `primary`.
                string selector_header = selector_match_info.fetch (1);
                MatchInfo class_match_info;
                if (!selector_class_regex.match (selector_header, 0, out class_match_info)) {
                    continue;
                }

                do {
                    string css_class = class_match_info.fetch (1).strip ();
                    if (css_class != "") {
                        class_set.insert (css_class, true);
                    }
                } while (class_match_info.next ());
            } while (selector_match_info.next ());
        } catch (RegexError e) {
            return;
        }
    }

    private static string strip_css_comments (string content) {
        if (!ensure_regexes_initialized () || block_comment_regex == null) {
            return content;
        }

        try {
            return block_comment_regex.replace (content, content.length, 0, "");
        } catch (RegexError e) {
            return content;
        }
    }

    private static bool ensure_regexes_initialized () {
        if (import_regex != null && block_comment_regex != null
            && selector_header_regex != null && selector_class_regex != null) {
            return true;
        }

        try {
            import_regex = new Regex ("@import\\s+url\\([\"']([^\"']+)[\"']\\)\\s*;");
            block_comment_regex = new Regex ("(?s)/\\*.*?\\*/");
            selector_header_regex = new Regex ("([^{}]+)\\{");
            selector_class_regex = new Regex ("\\.([A-Za-z_][A-Za-z0-9_-]*)");
            return true;
        } catch (RegexError e) {
            import_regex = null;
            block_comment_regex = null;
            selector_header_regex = null;
            selector_class_regex = null;
            return false;
        }
    }

    private static string to_absolute_path (string path) {
        if (Path.is_absolute (path)) {
            return path;
        }

        return Path.build_filename (Environment.get_current_dir (), path);
    }

    private static string? resolve_import_path (string importer_css_path, string import_target) {
        string target = import_target.strip ();
        if (target == "") {
            return null;
        }

        if (target.index_of ("://") >= 0 || target.has_prefix ("~")) {
            return null;
        }

        if (Path.is_absolute (target)) {
            return target;
        }

        string importer_dir = Path.get_dirname (importer_css_path);
        return Path.build_filename (importer_dir, target);
    }
}