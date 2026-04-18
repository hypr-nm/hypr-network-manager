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

    private class SelectorAnalysis : Object {
        public int id_count;
        public int class_like_count;
        public int type_like_count;
        public string[] selector_classes;

        public SelectorAnalysis () {
            this.id_count = 0;
            this.class_like_count = 0;
            this.type_like_count = 0;
            this.selector_classes = {};
        }
    }

    private class SelectorPatternIndex : Object {
        public string[] pattern_keys;

        public SelectorPatternIndex () {
            this.pattern_keys = {};
        }

        public void add_pattern_key (string pattern_key) {
            string normalized = pattern_key.strip ();
            if (normalized == "") {
                return;
            }

            foreach (string existing_key in this.pattern_keys) {
                if (existing_key == normalized) {
                    return;
                }
            }

            this.pattern_keys += normalized;
        }
    }

    private HashTable<string, ClassSpecificityStats>? indexed_classes = null;
    private HashTable<string, SelectorPatternIndex>? indexed_class_patterns = null;
    private string? indexed_base_css_path = null;
    private Regex? import_regex = null;
    private Regex? block_comment_regex = null;
    private Regex? selector_header_regex = null;

    public static void initialize (string base_css_path, bool force_reload = false) {
        if (base_css_path.strip () == "") {
            return;
        }

        if (!force_reload && indexed_classes != null && indexed_base_css_path == base_css_path) {
            return;
        }

        var class_set = new HashTable<string, ClassSpecificityStats> (str_hash, str_equal);
        var class_pattern_set = new HashTable<string, SelectorPatternIndex> (str_hash, str_equal);
        var visited_files = new HashTable<string, bool> (str_hash, str_equal);

        index_css_file (
            to_absolute_path (base_css_path),
            class_set,
            class_pattern_set,
            visited_files
        );

        indexed_classes = class_set;
        indexed_class_patterns = class_pattern_set;
        indexed_base_css_path = base_css_path;
    }

    public static void add_hook_and_best_class (
        Gtk.Widget widget,
        string hook_class,
        string[] class_hierarchy
    ) {
        string normalized_hook = hook_class.strip ();
        if (normalized_hook != "") {
            widget.add_css_class (normalized_hook);
        }

        add_best_class (widget, class_hierarchy);
    }

    public static void add_best_class (Gtk.Widget widget, string[] class_hierarchy) {
        string selected_class = resolve_best_class_with_existing_classes (
            class_hierarchy,
            widget.get_css_classes ()
        );
        if (selected_class == "") {
            return;
        }

        add_resolved_class (widget, selected_class);
    }

    public static string resolve_best_class (string[] class_hierarchy) {
        return resolve_best_class_with_existing_classes (class_hierarchy, {});
    }

    private static string resolve_best_class_with_existing_classes (
        string[] class_hierarchy,
        string[] existing_classes
    ) {
        string[] clean_hierarchy = sanitize_classes (class_hierarchy);
        if (clean_hierarchy.length == 0) {
            return "";
        }

        string fallback_class = resolve_fallback_class (clean_hierarchy);

        if (indexed_classes == null || indexed_classes.size () == 0 || indexed_class_patterns == null) {
            return fallback_class;
        }

        HashTable<string, bool> active_class_set = build_active_class_set (
            clean_hierarchy,
            existing_classes
        );

        string best_combo = resolve_best_combination (clean_hierarchy, active_class_set);
        if (best_combo != "") {
            return best_combo;
        }

        string best_class = "";
        unowned ClassSpecificityStats? best_stats = null;
        int best_hierarchy_index = int.MAX;

        for (int i = 0; i < clean_hierarchy.length; i++) {
            string candidate = clean_hierarchy[i];
            unowned ClassSpecificityStats? candidate_stats = resolve_candidate_stats (
                candidate,
                active_class_set
            );
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

    private static void add_resolved_class (Gtk.Widget widget, string resolved_class) {
        string normalized = resolved_class.strip ();
        if (normalized == "") {
            return;
        }

        if (normalized.index_of (".") < 0) {
            if (!widget.has_css_class (normalized)) {
                widget.add_css_class (normalized);
            }
            return;
        }

        string[] class_parts = normalized.split (".");
        foreach (string class_part in class_parts) {
            string css_class = class_part.strip ();
            if (css_class == "") {
                continue;
            }

            if (!widget.has_css_class (css_class)) {
                widget.add_css_class (css_class);
            }
        }
    }

    private static string[] sanitize_classes (string[] classes) {
        var seen = new HashTable<string, bool> (str_hash, str_equal);
        string[] sanitized = {};

        foreach (string raw_class in classes) {
            string normalized = raw_class.strip ();
            if (normalized == "" || seen.contains (normalized)) {
                continue;
            }

            seen.insert (normalized, true);
            sanitized += normalized;
        }

        return sanitized;
    }

    private static HashTable<string, bool> build_active_class_set (
        string[] class_hierarchy,
        string[] existing_classes
    ) {
        var active_class_set = new HashTable<string, bool> (str_hash, str_equal);

        foreach (string class_name in class_hierarchy) {
            string normalized = class_name.strip ();
            if (normalized != "") {
                active_class_set.insert (normalized, true);
            }
        }

        foreach (string class_name in existing_classes) {
            string normalized = class_name.strip ();
            if (normalized != "") {
                active_class_set.insert (normalized, true);
            }
        }

        return active_class_set;
    }

    private static unowned ClassSpecificityStats? resolve_candidate_stats (
        string candidate,
        HashTable<string, bool> active_class_set
    ) {
        if (indexed_classes == null || indexed_class_patterns == null) {
            return null;
        }

        unowned SelectorPatternIndex? pattern_index = indexed_class_patterns.lookup (candidate);
        if (pattern_index == null || pattern_index.pattern_keys.length == 0) {
            return null;
        }

        unowned ClassSpecificityStats? best_stats = null;

        foreach (string pattern_key in pattern_index.pattern_keys) {
            if (!combination_matches_active_classes (pattern_key, active_class_set)) {
                continue;
            }

            unowned ClassSpecificityStats? pattern_stats = indexed_classes.lookup (pattern_key);
            if (pattern_stats == null) {
                continue;
            }

            if (best_stats == null || compare_specificity (pattern_stats, best_stats) > 0) {
                best_stats = pattern_stats;
            }
        }

        return best_stats;
    }

    private static string resolve_best_combination (
        string[] class_hierarchy,
        HashTable<string, bool> active_class_set
    ) {
        if (indexed_classes == null || class_hierarchy.length < 2) {
            return "";
        }

        string best_combo = "";
        unowned ClassSpecificityStats? best_stats = null;
        int best_combo_length = 0;
        int best_combo_start = int.MAX;

        for (int combo_length = class_hierarchy.length; combo_length >= 2; combo_length--) {
            for (int start_index = 0; start_index + combo_length <= class_hierarchy.length; start_index++) {
                string combo_key = build_window_combo_key (class_hierarchy, start_index, combo_length);
                if (combo_key == "") {
                    continue;
                }

                unowned ClassSpecificityStats? combo_stats = indexed_classes.lookup (combo_key);
                if (combo_stats == null) {
                    continue;
                }

                if (!combination_matches_active_classes (combo_key, active_class_set)) {
                    continue;
                }

                int comparison = 0;
                if (best_stats != null) {
                    comparison = compare_specificity (combo_stats, best_stats);
                }

                if (best_stats == null
                    || comparison > 0
                    || (comparison == 0 && combo_length > best_combo_length)
                    || (comparison == 0 && combo_length == best_combo_length && start_index < best_combo_start)
                    || (comparison == 0
                        && combo_length == best_combo_length
                        && start_index == best_combo_start
                        && combo_key < best_combo)) {
                    best_combo = combo_key;
                    best_stats = combo_stats;
                    best_combo_length = combo_length;
                    best_combo_start = start_index;
                }
            }
        }

        return best_combo;
    }

    private static string build_window_combo_key (
        string[] class_hierarchy,
        int start_index,
        int combo_length
    ) {
        if (combo_length <= 1 || start_index < 0 || start_index + combo_length > class_hierarchy.length) {
            return "";
        }

        var key_builder = new StringBuilder ();
        for (int i = 0; i < combo_length; i++) {
            if (i > 0) {
                key_builder.append_c ('.');
            }

            key_builder.append (class_hierarchy[start_index + i]);
        }

        return key_builder.str;
    }

    private static bool combination_matches_active_classes (
        string combo_key,
        HashTable<string, bool> active_class_set
    ) {
        string normalized = combo_key.strip ();
        if (normalized == "") {
            return false;
        }

        string[] combo_parts = normalized.split (".");
        foreach (string combo_part in combo_parts) {
            string class_name = combo_part.strip ();
            if (class_name == "" || !active_class_set.contains (class_name)) {
                return false;
            }
        }

        return true;
    }

    private static int compare_specificity (ClassSpecificityStats a, ClassSpecificityStats b) {
        // GTK matching behavior is more practical when class-like selectors lead.
        if (a.class_like_count > b.class_like_count) {
            return 1;
        }

        if (a.class_like_count < b.class_like_count) {
            return -1;
        }

        if (a.type_like_count > b.type_like_count) {
            return 1;
        }

        if (a.type_like_count < b.type_like_count) {
            return -1;
        }

        if (a.id_count > b.id_count) {
            return 1;
        }

        if (a.id_count < b.id_count) {
            return -1;
        }

        if (a.source_order > b.source_order) {
            return 1;
        }

        if (a.source_order < b.source_order) {
            return -1;
        }

        return 0;
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
        HashTable<string, SelectorPatternIndex> class_pattern_set,
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

        index_imported_files (
            normalized_path,
            content_without_comments,
            class_set,
            class_pattern_set,
            visited_files
        );
        index_classes (content_without_comments, class_set, class_pattern_set);
    }

    private static void index_imported_files (
        string importer_css_path,
        string content,
        HashTable<string, ClassSpecificityStats> class_set,
        HashTable<string, SelectorPatternIndex> class_pattern_set,
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
                    index_css_file (import_path, class_set, class_pattern_set, visited_files);
                }
            } while (match_info.next ());
        } catch (RegexError e) {
            return;
        }
    }

    private static void index_classes (
        string content,
        HashTable<string, ClassSpecificityStats> class_set,
        HashTable<string, SelectorPatternIndex> class_pattern_set
    ) {
        if (!ensure_regexes_initialized () || selector_header_regex == null) {
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
                index_selector_group (
                    selector_header,
                    class_set,
                    class_pattern_set,
                    ref selector_order
                );
            } while (selector_match_info.next ());
        } catch (RegexError e) {
            return;
        }
    }

    private static void index_selector_group (
        string selector_group,
        HashTable<string, ClassSpecificityStats> class_set,
        HashTable<string, SelectorPatternIndex> class_pattern_set,
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
                index_single_selector (
                    current_selector.str,
                    class_set,
                    class_pattern_set,
                    selector_order
                );
                selector_order++;
                current_selector.truncate (0);
                continue;
            }

            current_selector.append_c (ch);
        }

        index_single_selector (
            current_selector.str,
            class_set,
            class_pattern_set,
            selector_order
        );
        selector_order++;
    }

    private static void index_single_selector (
        string selector,
        HashTable<string, ClassSpecificityStats> class_set,
        HashTable<string, SelectorPatternIndex> class_pattern_set,
        int selector_order
    ) {
        string selector_text = selector.strip ();
        if (selector_text == "") {
            return;
        }

        SelectorAnalysis analysis = analyze_target_selector (selector_text);
        if (analysis.selector_classes.length == 0) {
            return;
        }

        string pattern_key = create_pattern_key (analysis.selector_classes);
        if (pattern_key == "") {
            return;
        }

        var new_stats = new ClassSpecificityStats (
            analysis.id_count,
            analysis.class_like_count,
            analysis.type_like_count,
            selector_order
        );

        upsert_specificity (class_set, pattern_key, new_stats);

        foreach (string css_class in analysis.selector_classes) {
            SelectorPatternIndex pattern_index = get_or_create_pattern_index (
                class_pattern_set,
                css_class
            );
            pattern_index.add_pattern_key (pattern_key);
        }
    }

    private static void upsert_specificity (
        HashTable<string, ClassSpecificityStats> class_set,
        string key,
        ClassSpecificityStats candidate_stats
    ) {
        string normalized = key.strip ();
        if (normalized == "") {
            return;
        }

        unowned ClassSpecificityStats? existing_stats = class_set.lookup (normalized);
        if (existing_stats == null || compare_specificity (candidate_stats, existing_stats) > 0) {
            class_set.insert (normalized, candidate_stats);
        }
    }

    private static SelectorPatternIndex get_or_create_pattern_index (
        HashTable<string, SelectorPatternIndex> class_pattern_set,
        string css_class
    ) {
        unowned SelectorPatternIndex? existing_index = class_pattern_set.lookup (css_class);
        if (existing_index != null) {
            return existing_index;
        }

        var new_index = new SelectorPatternIndex ();
        class_pattern_set.insert (css_class, new_index);
        return new_index;
    }

    private static string create_pattern_key (string[] selector_classes) {
        if (selector_classes.length == 0) {
            return "";
        }

        if (selector_classes.length == 1) {
            return selector_classes[0];
        }

        var pattern_builder = new StringBuilder ();
        for (int i = 0; i < selector_classes.length; i++) {
            if (i > 0) {
                pattern_builder.append_c ('.');
            }

            pattern_builder.append (selector_classes[i]);
        }

        return pattern_builder.str;
    }

    private static SelectorAnalysis analyze_target_selector (string selector_text) {
        var analysis = new SelectorAnalysis ();

        int i = 0;
        while (i < selector_text.length) {
            char ch = selector_text[i];

            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
                || ch == '>' || ch == '+' || ch == '~' || ch == ',' || ch == '*') {
                i++;
                continue;
            }

            if (ch == '"' || ch == '\'') {
                i = skip_quoted_string (selector_text, i);
                continue;
            }

            if (ch == '[') {
                analysis.class_like_count++;
                i = skip_attribute_selector (selector_text, i + 1);
                continue;
            }

            if (ch == '#') {
                i++;
                string id_name = read_identifier (selector_text, ref i);
                if (id_name != "") {
                    analysis.id_count++;
                }
                continue;
            }

            if (ch == '.') {
                i++;
                string class_name = read_identifier (selector_text, ref i);
                if (class_name != "") {
                    analysis.class_like_count++;
                    add_unique_class_part (ref analysis.selector_classes, class_name);
                }
                continue;
            }

            if (ch == ':') {
                if (i + 1 < selector_text.length && selector_text[i + 1] == ':') {
                    i += 2;
                    string pseudo_element_name = read_identifier (selector_text, ref i);
                    if (pseudo_element_name != "") {
                        analysis.type_like_count++;
                    }

                    if (i < selector_text.length && selector_text[i] == '(') {
                        i = skip_parenthesized_block (selector_text, i + 1);
                    }
                    continue;
                }

                i++;
                string pseudo_class_name = read_identifier (selector_text, ref i);
                if (pseudo_class_name != "") {
                    analysis.class_like_count++;
                }

                if (i < selector_text.length && selector_text[i] == '(') {
                    i = skip_parenthesized_block (selector_text, i + 1);
                }
                continue;
            }

            if (is_identifier_start (ch)) {
                string type_name = read_identifier (selector_text, ref i);
                if (type_name != "") {
                    analysis.type_like_count++;
                }
                continue;
            }

            i++;
        }

        return analysis;
    }

    private static void add_unique_class_part (ref string[] selector_classes, string class_name) {
        string normalized = class_name.strip ();
        if (normalized == "") {
            return;
        }

        foreach (string existing_class in selector_classes) {
            if (existing_class == normalized) {
                return;
            }
        }

        string[] expanded_classes = new string[selector_classes.length + 1];
        for (int i = 0; i < selector_classes.length; i++) {
            expanded_classes[i] = selector_classes[i];
        }

        expanded_classes[selector_classes.length] = normalized;
        selector_classes = expanded_classes;
    }

    private static string read_identifier (string text, ref int index) {
        if (index >= text.length || !is_identifier_start (text[index])) {
            return "";
        }

        int start = index;
        index++;
        while (index < text.length && is_identifier_char (text[index])) {
            index++;
        }

        return text.substring (start, index - start);
    }

    private static int skip_parenthesized_block (string text, int start_index) {
        int depth = 1;
        int i = start_index;

        while (i < text.length) {
            char ch = text[i];

            if (ch == '"' || ch == '\'') {
                i = skip_quoted_string (text, i);
                continue;
            }

            if (ch == '(') {
                depth++;
                i++;
                continue;
            }

            if (ch == ')') {
                depth--;
                i++;
                if (depth <= 0) {
                    return i;
                }
                continue;
            }

            i++;
        }

        return i;
    }

    private static int skip_attribute_selector (string text, int start_index) {
        int depth = 1;
        int i = start_index;

        while (i < text.length) {
            char ch = text[i];

            if (ch == '"' || ch == '\'') {
                i = skip_quoted_string (text, i);
                continue;
            }

            if (ch == '[') {
                depth++;
                i++;
                continue;
            }

            if (ch == ']') {
                depth--;
                i++;
                if (depth <= 0) {
                    return i;
                }
                continue;
            }

            i++;
        }

        return i;
    }

    private static int skip_quoted_string (string text, int quote_index) {
        char quote_char = text[quote_index];
        int i = quote_index + 1;

        while (i < text.length) {
            char ch = text[i];
            if (ch == '\\') {
                i += 2;
                continue;
            }

            if (ch == quote_char) {
                return i + 1;
            }

            i++;
        }

        return i;
    }

    private static bool is_identifier_start (char ch) {
        return (ch >= 'A' && ch <= 'Z')
            || (ch >= 'a' && ch <= 'z')
            || ch == '_'
            || ch == '-';
    }

    private static bool is_identifier_char (char ch) {
        return is_identifier_start (ch)
            || (ch >= '0' && ch <= '9');
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
            && selector_header_regex != null) {
            return true;
        }

        try {
            import_regex = new Regex ("@import\\s+url\\([\"']([^\"']+)[\"']\\)\\s*;");
            block_comment_regex = new Regex ("(?s)/\\*.*?\\*/");
            selector_header_regex = new Regex ("([^{}]+)\\{");
            return true;
        } catch (RegexError e) {
            import_regex = null;
            block_comment_regex = null;
            selector_header_regex = null;
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
