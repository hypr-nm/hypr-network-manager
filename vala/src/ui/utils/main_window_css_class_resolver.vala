using GLib;
using Gtk;

namespace MainWindowCssClassResolver {
    private class ClassSpecificityStats : Object {
        public int id_count;
        public int class_like_count;
        public int type_like_count;
        public int source_order;

        public ClassSpecificityStats (
            int id_count,
            int class_like_count,
            int type_like_count,
            int source_order
        ) {
            this.id_count = id_count;
            this.class_like_count = class_like_count;
            this.type_like_count = type_like_count;
            this.source_order = source_order;
        }
    }

    private HashTable<string, ClassSpecificityStats>? indexed_classes = null;
    private string? indexed_base_css_path = null;
    private Regex? import_regex = null;
    private Regex? block_comment_regex = null;
    private Regex? selector_header_regex = null;
    private Regex? selector_class_regex = null;
    private Regex? selector_id_regex = null;
    private Regex? selector_attribute_regex = null;
    private Regex? selector_pseudo_element_regex = null;
    private Regex? selector_pseudo_class_regex = null;
    private Regex? selector_type_regex = null;

    public static void initialize (string base_css_path) {
        if (base_css_path.strip () == "") {
            return;
        }

        if (indexed_classes != null && indexed_base_css_path == base_css_path) {
            return;
        }

        var class_set = new HashTable<string, ClassSpecificityStats> (str_hash, str_equal);
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
        unowned ClassSpecificityStats? best_stats = null;
        int best_hierarchy_index = int.MAX;

        for (int i = 0; i < class_hierarchy.length; i++) {
            string candidate = class_hierarchy[i].strip ();
            if (candidate == "") {
                continue;
            }

            unowned ClassSpecificityStats? candidate_stats = indexed_classes.lookup (candidate);
            if (candidate_stats == null) {
                continue;
            }

            int comparison = 0;
            if (best_stats != null) {
                comparison = compare_specificity (candidate_stats, best_stats);
            }

            if (best_stats == null
                || comparison > 0
                || (comparison == 0 && i < best_hierarchy_index)
                || (comparison == 0 && i == best_hierarchy_index && candidate < best_class)) {
                best_class = candidate;
                best_stats = candidate_stats;
                best_hierarchy_index = i;
            }
        }

        if (best_class != "") {
            return best_class;
        }

        return fallback_class;
    }

    private static int compare_specificity (ClassSpecificityStats a, ClassSpecificityStats b) {
        if (a.id_count != b.id_count) {
            return a.id_count - b.id_count;
        }

        if (a.class_like_count != b.class_like_count) {
            return a.class_like_count - b.class_like_count;
        }

        if (a.type_like_count != b.type_like_count) {
            return a.type_like_count - b.type_like_count;
        }

        return a.source_order - b.source_order;
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
        HashTable<string, ClassSpecificityStats> class_set,
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
        HashTable<string, ClassSpecificityStats> class_set,
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

    private static void index_classes (string content, HashTable<string, ClassSpecificityStats> class_set) {
        if (!ensure_regexes_initialized () || selector_header_regex == null || selector_class_regex == null) {
            return;
        }

        try {
            MatchInfo selector_match_info;
            if (!selector_header_regex.match (content, 0, out selector_match_info)) {
                return;
            }

            int selector_order = 0;
            do {
                string selector_header = selector_match_info.fetch (1);
                index_selector_group (selector_header, class_set, ref selector_order);
            } while (selector_match_info.next ());
        } catch (RegexError e) {
            return;
        }
    }

    private static void index_selector_group (
        string selector_group,
        HashTable<string, ClassSpecificityStats> class_set,
        ref int selector_order
    ) {
        var current_selector = new StringBuilder ();
        int parentheses_depth = 0;
        int bracket_depth = 0;
        char active_quote = '\0';

        for (int i = 0; i < selector_group.length; i++) {
            char ch = selector_group[i];

            if (active_quote != '\0') {
                current_selector.append_c (ch);
                if (ch == active_quote) {
                    active_quote = '\0';
                }
                continue;
            }

            if (ch == '"' || ch == '\'') {
                active_quote = ch;
                current_selector.append_c (ch);
                continue;
            }

            if (ch == '(') {
                parentheses_depth++;
                current_selector.append_c (ch);
                continue;
            }

            if (ch == ')' && parentheses_depth > 0) {
                parentheses_depth--;
                current_selector.append_c (ch);
                continue;
            }

            if (ch == '[') {
                bracket_depth++;
                current_selector.append_c (ch);
                continue;
            }

            if (ch == ']' && bracket_depth > 0) {
                bracket_depth--;
                current_selector.append_c (ch);
                continue;
            }

            if (ch == ',' && parentheses_depth == 0 && bracket_depth == 0) {
                index_single_selector (current_selector.str, class_set, selector_order);
                selector_order++;
                current_selector.truncate (0);
                continue;
            }

            current_selector.append_c (ch);
        }

        index_single_selector (current_selector.str, class_set, selector_order);
        selector_order++;
    }

    private static void index_single_selector (
        string selector,
        HashTable<string, ClassSpecificityStats> class_set,
        int selector_order
    ) {
        if (!ensure_regexes_initialized ()
            || selector_class_regex == null
            || selector_id_regex == null
            || selector_attribute_regex == null
            || selector_pseudo_element_regex == null
            || selector_pseudo_class_regex == null
            || selector_type_regex == null) {
            return;
        }

        string selector_text = selector.strip ();
        if (selector_text == "") {
            return;
        }

        int id_count = count_matches (selector_id_regex, selector_text);
        int class_count = count_matches (selector_class_regex, selector_text);
        int attribute_count = count_matches (selector_attribute_regex, selector_text);
        int pseudo_element_count = count_matches (selector_pseudo_element_regex, selector_text);
        int pseudo_class_count = count_matches (selector_pseudo_class_regex, selector_text);

        int class_like_count = class_count + attribute_count + pseudo_class_count;
        int type_like_count = pseudo_element_count + count_type_selectors (selector_text);

        MatchInfo class_match_info;
        if (!selector_class_regex.match (selector_text, 0, out class_match_info)) {
            return;
        }

        while (true) {
            string css_class = class_match_info.fetch (1).strip ();
            if (css_class == "") {
                try {
                    if (!class_match_info.next ()) {
                        break;
                    }
                } catch (RegexError e) {
                    break;
                }
                continue;
            }

            var new_stats = new ClassSpecificityStats (
                id_count,
                class_like_count,
                type_like_count,
                selector_order
            );

            unowned ClassSpecificityStats? existing_stats = class_set.lookup (css_class);
            if (existing_stats == null || compare_specificity (new_stats, existing_stats) > 0) {
                class_set.insert (css_class, new_stats);
            }

            try {
                if (!class_match_info.next ()) {
                    break;
                }
            } catch (RegexError e) {
                break;
            }
        }
    }

    private static int count_type_selectors (string selector_text) {
        if (!ensure_regexes_initialized ()
            || selector_id_regex == null
            || selector_class_regex == null
            || selector_attribute_regex == null
            || selector_pseudo_element_regex == null
            || selector_pseudo_class_regex == null
            || selector_type_regex == null) {
            return 0;
        }

        string reduced = selector_text;
        reduced = replace_regex (selector_id_regex, reduced, " ");
        reduced = replace_regex (selector_class_regex, reduced, " ");
        reduced = replace_regex (selector_attribute_regex, reduced, " ");
        reduced = replace_regex (selector_pseudo_element_regex, reduced, " ");
        reduced = replace_regex (selector_pseudo_class_regex, reduced, " ");
        return count_matches (selector_type_regex, reduced);
    }

    private static int count_matches (Regex regex, string text) {
        try {
            MatchInfo match_info;
            if (!regex.match (text, 0, out match_info)) {
                return 0;
            }

            int count = 0;
            do {
                count++;
            } while (match_info.next ());
            return count;
        } catch (RegexError e) {
            return 0;
        }
    }

    private static string replace_regex (Regex regex, string text, string replacement) {
        try {
            return regex.replace (text, text.length, 0, replacement);
        } catch (RegexError e) {
            return text;
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
            && selector_header_regex != null && selector_class_regex != null
            && selector_id_regex != null && selector_attribute_regex != null
            && selector_pseudo_element_regex != null && selector_pseudo_class_regex != null
            && selector_type_regex != null) {
            return true;
        }

        try {
            import_regex = new Regex ("@import\\s+url\\([\"']([^\"']+)[\"']\\)\\s*;");
            block_comment_regex = new Regex ("(?s)/\\*.*?\\*/");
            selector_header_regex = new Regex ("([^{}]+)\\{");
            selector_class_regex = new Regex ("\\.([A-Za-z_][A-Za-z0-9_-]*)");
            selector_id_regex = new Regex ("#([A-Za-z_][A-Za-z0-9_-]*)");
            selector_attribute_regex = new Regex ("\\[[^\\]]+\\]");
            selector_pseudo_element_regex = new Regex ("::[A-Za-z_][A-Za-z0-9_-]*");
            selector_pseudo_class_regex = new Regex ("(?<!:):(?!:)[A-Za-z_][A-Za-z0-9_-]*(\\([^)]*\\))?");
            selector_type_regex = new Regex ("(^|[\\s>+~(,])([A-Za-z_][A-Za-z0-9_-]*)");
            return true;
        } catch (RegexError e) {
            import_regex = null;
            block_comment_regex = null;
            selector_header_regex = null;
            selector_class_regex = null;
            selector_id_regex = null;
            selector_attribute_regex = null;
            selector_pseudo_element_regex = null;
            selector_pseudo_class_regex = null;
            selector_type_regex = null;
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