using GLib;

public class MainWindowAsyncExecutor : Object {
    public static void dispatch(MainWindowActionCallback action) {
        Idle.add(() => {
            action();
            return false;
        });
    }

    public static bool run(
        MainWindowActionCallback worker,
        MainWindowErrorCallback? on_spawn_error = null,
        string spawn_error_prefix = "Async task failed"
    ) {
        try {
            new Thread<void>.try("hyp-nm-ui", () => {
                worker();
                return;
            });
            return true;
        } catch (ThreadError e) {
            if (on_spawn_error != null) {
                string message = e.message;
                dispatch(() => {
                    on_spawn_error(spawn_error_prefix + ": " + message);
                });
            }
            return false;
        }
    }
}
