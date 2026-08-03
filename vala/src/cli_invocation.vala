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

public class CliInvocation : GLib.Object {
    public const string DAEMON_OPTION = "--daemon";
    public const string DEBUG_OPTION = "--debug";
    public const string CONFIG_OPTION = "--config";

    public static string[] build_daemon_args (
        string executable,
        bool debug_enabled,
        string? config_path
    ) {
        string[] args = { executable, DAEMON_OPTION };
        if (debug_enabled) {
            args += DEBUG_OPTION;
        }
        if (config_path != null) {
            args += CONFIG_OPTION;
            args += config_path;
        }
        return args;
    }
}
