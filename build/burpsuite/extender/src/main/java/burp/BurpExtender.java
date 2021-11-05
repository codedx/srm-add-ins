package burp;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.*;

/***
 * This implementation is an extension that generates an XML report when it detects
 * a new file in the generate-report-burp-extender directory under the 'temp' directory. A
 * file whose name starts with 'generate-report-' will create a report file with a filename
 * based on what comes after 'generate-report-'. For example, to create a report named
 * output.xml, create a file named generate-report-output.xml.
 *
 * The Burp Suite API does not provide support for generating XML reports. The JSON results
 * obtained from the API do not map one-to-one with the Burp Suite XML format, so this
 * extension uses the Burp report generator instead of custom JSON-to-XML transformation code.
 */
public class BurpExtender implements IBurpExtender
{
	private static final String GENERATE_REPORT_PREFIX = "generate-report-";
	private final Path directoryToWatch = Paths.get(getDirectoryPathToWatch());

	public static String getDirectoryPathToWatch() {
		String directoryToWatch = System.getenv("GENERATE_REPORT_DIRECTORY");
		return directoryToWatch != null ? directoryToWatch : new File(System.getProperty("java.io.tmpdir"), "generate-report-burp-extender").toString();
	}

	@Override
	public void registerExtenderCallbacks(IBurpExtenderCallbacks callbacks)
	{
		callbacks.setExtensionName("Generate Report Extender");

		PrintWriter stdout = new PrintWriter(callbacks.getStdout(), true);
		PrintWriter stderr = new PrintWriter(callbacks.getStderr(), true);

		java.io.File directory = directoryToWatch.toFile();
		stdout.println(String.format("Starting extension to watch directory '%s'...", directory.toString()));

		if (!directory.exists()) {
			stdout.println("Creating watch directory...");
			if (!directory.mkdir()) {
				stderr.println("ERROR: Exiting after create directory failure");
				return;
			}
		}

		Runnable runnable =	() -> {
			try {
				WatchService watcher;
				try {
					watcher = FileSystems.getDefault().newWatchService();
				} catch (IOException e) {
					stderr.println(String.format("ERROR: Exiting after an I/O exception creating a new watch service: %s", e.toString()));
					return;
				}

				try {
					directoryToWatch.register(watcher, StandardWatchEventKinds.ENTRY_CREATE);
				} catch (IOException e) {
					stderr.println(String.format("ERROR: Exiting after an I/O exception registering a folder watch for '%s': %s", directoryToWatch.toString(), e.toString()));
					return;
				}

				for (; ; ) {
					WatchKey key;
					try {
						key = watcher.take();
					} catch (InterruptedException x) {
						stderr.println(String.format("ERROR: Exiting after interruption while waiting for watcher key signal: %s", x.toString()));
						return;
					}

					for (WatchEvent<?> event : key.pollEvents()) {
						WatchEvent.Kind<?> kind = event.kind();
						if (kind == StandardWatchEventKinds.OVERFLOW) {
							continue;
						}

						WatchEvent<Path> ev = (WatchEvent<Path>) event;
						Path filename = ev.context().getFileName();

						stdout.println(String.format("Detected file %s", filename.toString()));
						if (!filename.toString().startsWith(GENERATE_REPORT_PREFIX)) {
							continue;
						}

						IScanIssue[] issues = callbacks.getScanIssues(null);

						String reportFilename = filename.toString().replaceFirst(GENERATE_REPORT_PREFIX, "");
						if (reportFilename.startsWith(GENERATE_REPORT_PREFIX)) {
							// avoid creating a report that would be interpreted as another request to create a report
							stderr.println(String.format("The file '%s' is invalid", filename));
							continue;
						}

						File reportPath = new File(directoryToWatch.toString(), reportFilename);

						stdout.println(String.format("Creating report file '%s' with %d scan issues...", reportPath.toString(), issues == null ? 0 : issues.length));
						callbacks.generateScanReport("XML", issues, reportPath);

						// delete the generate-report file to indicate report creation
						File reportRequestPath = new File(directoryToWatch.toString(), filename.toString());
						stdout.println(String.format("Removing generate-report file %s", reportRequestPath.toString()));
						if (!reportRequestPath.delete()) {
							stderr.println(String.format("Unable to delete generate-report file %s", filename.toString()));
						}
					}

					stdout.println("Resetting watch key...");
					if (!key.reset()) {
						stderr.println("ERROR: Exiting after failure to reset watch key");
						return;
					}
				}
			} catch (Exception e) {
				stderr.println(String.format("ERROR: Extension ending with unexpected error: %s", e.toString()));
			}
		};

		Thread watchThread = new Thread(runnable, "Generate Report Extension Thread");
		watchThread.setDaemon(true);

		stdout.println(String.format("Starting thread %s...", watchThread.getName()));
		watchThread.start();
	}
}
