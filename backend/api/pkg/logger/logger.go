// Package logger provides a structured, levelled logging abstraction backed
// by zerolog. All application code logs through this package rather than
// calling zerolog directly, keeping the logging implementation swappable.
//
// Usage:
//
//	log := logger.New(cfg.LogLevel)
//	log.Info("server started", logger.F("address", cfg.HTTPAddress))
package logger

import (
	"io"
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
)

// Logger is the application-level structured logger.
// It wraps zerolog.Logger and exposes a stable API so call sites do not
// import zerolog directly.
type Logger struct {
	zl zerolog.Logger
}

// Field is a key-value pair attached to a log entry.
type Field struct {
	key   string
	value any
}

// F constructs a Field. The value may be any type that zerolog can serialise.
func F(key string, value any) Field {
	return Field{key: key, value: value}
}

// New creates a Logger configured for the given level string.
// level must be one of: debug, info, warn, error (case-insensitive).
// Output is written to w; pass nil to default to os.Stdout.
func New(level string, w io.Writer) Logger {
	if w == nil {
		w = os.Stdout
	}

	zlLevel := parseLevel(level)
	zl := zerolog.New(w).
		Level(zlLevel).
		With().
		Timestamp().
		Str("service", "sherwood-api").
		Logger()

	return Logger{zl: zl}
}

// NewDevelopment creates a human-readable console logger for local development.
// Uses debug level and pretty-prints with colour.
func NewDevelopment() Logger {
	w := zerolog.ConsoleWriter{
		Out:        os.Stdout,
		TimeFormat: time.RFC3339,
	}
	zl := zerolog.New(w).
		Level(zerolog.DebugLevel).
		With().
		Timestamp().
		Str("service", "sherwood-api").
		Logger()
	return Logger{zl: zl}
}

// With returns a new Logger with the given fields pre-attached to every
// subsequent log entry. Use this to create request-scoped child loggers.
func (l Logger) With(fields ...Field) Logger {
	ctx := l.zl.With()
	for _, f := range fields {
		ctx = ctx.Interface(f.key, f.value)
	}
	return Logger{zl: ctx.Logger()}
}

// Info logs a message at INFO level.
func (l Logger) Info(msg string, fields ...Field) {
	l.event(l.zl.Info(), msg, fields)
}

// Warn logs a message at WARN level.
func (l Logger) Warn(msg string, fields ...Field) {
	l.event(l.zl.Warn(), msg, fields)
}

// Error logs a message and error at ERROR level.
// err may be nil; if non-nil it is attached as the "error" field.
func (l Logger) Error(msg string, err error, fields ...Field) {
	ev := l.zl.Error()
	if err != nil {
		ev = ev.Err(err)
	}
	l.event(ev, msg, fields)
}

// Debug logs a message at DEBUG level. No-op when the configured level
// is above debug.
func (l Logger) Debug(msg string, fields ...Field) {
	l.event(l.zl.Debug(), msg, fields)
}

// Fatal logs at ERROR level and then calls os.Exit(1).
// Reserved for unrecoverable startup failures.
func (l Logger) Fatal(msg string, err error, fields ...Field) {
	ev := l.zl.Fatal()
	if err != nil {
		ev = ev.Err(err)
	}
	l.event(ev, msg, fields)
}

// Zerolog returns the underlying zerolog.Logger for interop with libraries
// that accept a zerolog.Logger directly (e.g. gin-zerolog adapters).
func (l Logger) Zerolog() zerolog.Logger { return l.zl }

// ─── internal helpers ─────────────────────────────────────────────────────────

func (l Logger) event(ev *zerolog.Event, msg string, fields []Field) {
	for _, f := range fields {
		ev = ev.Interface(f.key, f.value)
	}
	ev.Msg(msg)
}

func parseLevel(s string) zerolog.Level {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug":
		return zerolog.DebugLevel
	case "warn", "warning":
		return zerolog.WarnLevel
	case "error":
		return zerolog.ErrorLevel
	default:
		return zerolog.InfoLevel
	}
}
