#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define ITG_DEFAULT_BUNDLE_ID   "com.kern0x1b.telegram"
#define ITG_DEFAULT_EXECUTABLE  "Telegram"
#define ITG_DEFAULT_INTERVAL    30
#define ITG_DEFAULT_COOLDOWN    180
#define ITG_DEFAULT_SETTLE      45
#define ITG_CONFIG_PATH         "/etc/telegramd.conf"
#define ITG_DISABLE_PATH        "/var/mobile/Library/Preferences/com.kern0x1b.telegram.nolaunch"
#define ITG_LOG_PATH            "/var/log/telegramd.log"
#define ITG_LOG_MAX_BYTES       262144
#define ITG_SBS_PATH \
	"/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices"

typedef int (*itg_launch_fn)(CFStringRef identifier, Boolean suspended);
typedef int (*itg_launch_options_fn)(CFStringRef identifier, CFDictionaryRef options,
									 Boolean suspended);
typedef const char *(*itg_error_string_fn)(int error);

static char itg_bundle_id[128] = ITG_DEFAULT_BUNDLE_ID;
static char itg_executable[64] = ITG_DEFAULT_EXECUTABLE;
static int itg_interval = ITG_DEFAULT_INTERVAL;
static int itg_cooldown = ITG_DEFAULT_COOLDOWN;
static int itg_settle = ITG_DEFAULT_SETTLE;
static int itg_dry_run = 0;
static volatile sig_atomic_t itg_should_stop = 0;

static void itg_handle_signal(int signo) {
	(void)signo;
	itg_should_stop = 1;
}

static void itg_rotate_log(void) {
	struct stat info;
	if (stat(ITG_LOG_PATH, &info) != 0)
		return;
	if (info.st_size < ITG_LOG_MAX_BYTES)
		return;
	rename(ITG_LOG_PATH, ITG_LOG_PATH ".1");
}

static void itg_log(const char *format, ...) {
	itg_rotate_log();

	FILE *out = fopen(ITG_LOG_PATH, "a");
	if (!out)
		out = stderr;

	time_t now = time(NULL);
	struct tm parts;
	localtime_r(&now, &parts);
	char stamp[32];
	strftime(stamp, sizeof(stamp), "%Y-%m-%d %H:%M:%S", &parts);
	fprintf(out, "%s telegramd ", stamp);

	va_list args;
	va_start(args, format);
	vfprintf(out, format, args);
	va_end(args);

	fputc('\n', out);
	fflush(out);
	if (out != stderr)
		fclose(out);
}

static void itg_trim(char *text) {
	size_t length = strlen(text);
	while (length && (text[length - 1] == '\n' || text[length - 1] == '\r' ||
					  text[length - 1] == ' ' || text[length - 1] == '\t'))
		text[--length] = '\0';
}

static void itg_load_config(void) {
	FILE *in = fopen(ITG_CONFIG_PATH, "r");
	if (!in)
		return;

	char line[256];
	while (fgets(line, sizeof(line), in)){
		itg_trim(line);
		if (!line[0] || line[0] == '#')
			continue;
		char *equals = strchr(line, '=');
		if (!equals)
			continue;
		*equals = '\0';
		const char *key = line;
		const char *value = equals + 1;

		if (strcmp(key, "bundle_id") == 0)
			strlcpy(itg_bundle_id, value, sizeof(itg_bundle_id));
		else if (strcmp(key, "executable") == 0)
			strlcpy(itg_executable, value, sizeof(itg_executable));
		else if (strcmp(key, "interval") == 0)
			itg_interval = atoi(value);
		else if (strcmp(key, "cooldown") == 0)
			itg_cooldown = atoi(value);
		else if (strcmp(key, "settle") == 0)
			itg_settle = atoi(value);
		else if (strcmp(key, "dry_run") == 0)
			itg_dry_run = atoi(value);
	}
	fclose(in);

	if (itg_interval < 5)
		itg_interval = 5;
	if (itg_cooldown < itg_interval)
		itg_cooldown = itg_interval;
}

static int itg_disabled(void) {
	struct stat info;
	return stat(ITG_DISABLE_PATH, &info) == 0;
}

static int itg_process_running(const char *executable) {
	int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
	size_t length = 0;

	if (sysctl(mib, 4, NULL, &length, NULL, 0) != 0)
		return -1;

	struct kinfo_proc *entries = malloc(length);
	if (!entries)
		return -1;

	if (sysctl(mib, 4, entries, &length, NULL, 0) != 0){
		free(entries);
		return -1;
	}

	int count = (int)(length / sizeof(struct kinfo_proc));
	int found = 0;
	for (int i = 0; i < count; i++){
		if (strncmp(entries[i].kp_proc.p_comm, executable, MAXCOMLEN) == 0){
			found = 1;
			break;
		}
	}

	free(entries);
	return found;
}

static void *itg_springboard_services(void) {
	static void *handle = NULL;
	static int attempted = 0;
	if (!attempted){
		attempted = 1;
		handle = dlopen(ITG_SBS_PATH, RTLD_LAZY | RTLD_GLOBAL);
		if (!handle)
			itg_log("dlopen SpringBoardServices failed: %s", dlerror());
	}
	return handle;
}

static int itg_launch_suspended(const char *bundleId) {
	void *handle = itg_springboard_services();
	if (!handle)
		return -1;

	CFStringRef identifier = CFStringCreateWithCString(NULL, bundleId, kCFStringEncodingUTF8);
	if (!identifier)
		return -1;

	int result = -1;
	const char *used = "none";

	itg_launch_options_fn withOptions =
			(itg_launch_options_fn)dlsym(handle, "SBSLaunchApplicationWithIdentifierAndLaunchOptions");
	itg_launch_fn plain =
			(itg_launch_fn)dlsym(handle, "SBSLaunchApplicationWithIdentifier");

	if (withOptions){
		used = "SBSLaunchApplicationWithIdentifierAndLaunchOptions";
		result = withOptions(identifier, NULL, true);
	} else if (plain){
		used = "SBSLaunchApplicationWithIdentifier";
		result = plain(identifier, true);
	} else {
		itg_log("no SBSLaunchApplication* symbol available");
	}

	if (result != 0){
		itg_error_string_fn describe =
				(itg_error_string_fn)dlsym(handle, "SBSApplicationLaunchingErrorString");
		const char *reason = describe ? describe(result) : NULL;
		itg_log("launch %s via %s failed: %d (%s)", bundleId, used, result,
				reason ? reason : "unknown");
	} else {
		itg_log("launch %s via %s suspended=1 ok", bundleId, used);
	}

	CFRelease(identifier);
	return result;
}

int main(int argc, char **argv) {
	(void)argc;
	(void)argv;

	signal(SIGTERM, itg_handle_signal);
	signal(SIGINT, itg_handle_signal);
	signal(SIGPIPE, SIG_IGN);

	itg_load_config();
	itg_log("start bundle=%s executable=%s interval=%d cooldown=%d settle=%d dry_run=%d",
			itg_bundle_id, itg_executable, itg_interval, itg_cooldown, itg_settle, itg_dry_run);

	time_t lastLaunch = 0;
	time_t startedAt = time(NULL);
	int wasRunning = -1;

	while (!itg_should_stop){
		sleep((unsigned int)itg_interval);
		if (itg_should_stop)
			break;

		if (itg_disabled()){
			if (wasRunning != -2){
				itg_log("disabled by %s", ITG_DISABLE_PATH);
				wasRunning = -2;
			}
			continue;
		}

		time_t now = time(NULL);
		if (now - startedAt < itg_settle)
			continue;

		int running = itg_process_running(itg_executable);
		if (running < 0){
			itg_log("process scan failed: %s", strerror(errno));
			continue;
		}

		if (running != wasRunning){
			itg_log("app running=%d", running);
			wasRunning = running;
		}

		if (running)
			continue;

		if (lastLaunch != 0 && now - lastLaunch < itg_cooldown)
			continue;

		lastLaunch = now;
		if (itg_dry_run){
			itg_log("dry_run: would launch %s suspended", itg_bundle_id);
			continue;
		}

		itg_launch_suspended(itg_bundle_id);
	}

	itg_log("stop");
	return 0;
}
