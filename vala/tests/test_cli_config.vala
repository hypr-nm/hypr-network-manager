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

using GLib;

private static void test_default_daemon_args () {
    string[] args = CliInvocation.build_daemon_args (
        "/usr/bin/hypr-network-manager",
        false,
        null
    );

    assert (args.length == 2);
    assert (args[0] == "/usr/bin/hypr-network-manager");
    assert (args[1] == CliInvocation.DAEMON_OPTION);
}

private static void test_forwarded_daemon_args () {
    string[] args = CliInvocation.build_daemon_args (
        "/opt/hypr-network-manager",
        true,
        "/tmp/custom config.json"
    );

    assert (args.length == 5);
    assert (args[0] == "/opt/hypr-network-manager");
    assert (args[1] == CliInvocation.DAEMON_OPTION);
    assert (args[2] == CliInvocation.DEBUG_OPTION);
    assert (args[3] == CliInvocation.CONFIG_OPTION);
    assert (args[4] == "/tmp/custom config.json");
}

private static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/cli/daemon-args/default", test_default_daemon_args);
    Test.add_func ("/cli/daemon-args/forwarded", test_forwarded_daemon_args);
    return Test.run ();
}
