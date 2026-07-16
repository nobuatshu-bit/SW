package http

import "runtime"

func init() {
	// Populate GoVersion at process start so it is always accurate,
	// even when -ldflags is not used.
	if GoVersion == "unknown" {
		GoVersion = runtime.Version()
	}
}
