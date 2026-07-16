// Package apierr defines the canonical error types for the SHERWOOD HTTP API.
//
// Every error that crosses an HTTP boundary is represented as an *Error value.
// Handlers call apierr constructors; the middleware layer serialises them to
// the standard JSON envelope:
//
//	{ "success": false, "error": { "code": "...", "message": "...", "field_errors": {...} } }
//
// Error codes are string constants shared with the TypeScript client in
// packages/shared/src/types/api-contract.types.ts — never change existing codes.
package apierr

import (
	"errors"
	"fmt"
	"net/http"
)

// Code is a machine-readable string constant returned in the JSON error body.
// The TypeScript client uses these to branch on error type without parsing messages.
type Code string

const (
	// Auth
	CodeInvalidAddress   Code = "INVALID_ADDRESS"
	CodeInvalidSignature Code = "INVALID_SIGNATURE"
	CodeNonceExpired     Code = "NONCE_EXPIRED"
	CodeAddressMismatch  Code = "ADDRESS_MISMATCH"
	CodeUnauthenticated  Code = "UNAUTHENTICATED"
	CodeForbidden        Code = "FORBIDDEN"

	// Resources
	CodeLaunchNotFound      Code = "LAUNCH_NOT_FOUND"
	CodeTokenNotDeployed    Code = "TOKEN_NOT_DEPLOYED"
	CodeTransactionNotFound Code = "TRANSACTION_NOT_FOUND"
	CodeWalletNotFound      Code = "WALLET_NOT_FOUND"
	CodeUserNotFound        Code = "USER_NOT_FOUND"

	// Validation / bad input
	CodeBadRequest                Code = "BAD_REQUEST"
	CodeValidationError           Code = "VALIDATION_ERROR"
	CodeInvalidFilter             Code = "INVALID_FILTER"
	CodeLaunchNotEditable         Code = "LAUNCH_NOT_EDITABLE"
	CodeMaxActiveLaunchesExceeded Code = "MAX_ACTIVE_LAUNCHES_EXCEEDED"

	// Server
	CodeInternalError       Code = "INTERNAL_ERROR"
	CodeServiceUnavailable  Code = "SERVICE_UNAVAILABLE"
)

// FieldErrors maps a field name to one or more validation messages.
// Used exclusively on 422 Unprocessable Entity responses.
type FieldErrors map[string][]string

// Error is the single error type used throughout the API layer.
// It implements the standard error interface so it can be returned from
// service and repository functions without special handling at every call site.
type Error struct {
	// HTTPStatus is the HTTP response code this error maps to.
	HTTPStatus int
	// Code is the machine-readable error code sent to the client.
	Code Code
	// Message is a human-readable description safe to expose publicly.
	Message string
	// FieldErrors contains per-field validation messages (422 only).
	FieldErrors FieldErrors
	// internal is an optional wrapped error kept server-side for logging.
	// It is never serialised into the response body.
	internal error
}

func (e *Error) Error() string {
	if e.internal != nil {
		return fmt.Sprintf("%s: %s (caused by: %s)", e.Code, e.Message, e.internal.Error())
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// Unwrap supports errors.Is / errors.As traversal.
func (e *Error) Unwrap() error { return e.internal }

// Internal returns the wrapped internal error (nil-safe).
func (e *Error) Internal() error { return e.internal }

// WithInternal returns a shallow copy of the error with the internal cause set.
// Use this to preserve the original error for server-side logging while still
// returning a sanitised message to the client.
func (e *Error) WithInternal(cause error) *Error {
	cp := *e
	cp.internal = cause
	return &cp
}

// ─── Constructors ─────────────────────────────────────────────────────────────

// New creates a generic API error with a custom HTTP status and code.
func New(httpStatus int, code Code, message string) *Error {
	return &Error{HTTPStatus: httpStatus, Code: code, Message: message}
}

// NotFound returns a 404 error for the given resource description.
func NotFound(code Code, resource string) *Error {
	return &Error{
		HTTPStatus: http.StatusNotFound,
		Code:       code,
		Message:    fmt.Sprintf("%s not found", resource),
	}
}

// Unauthorized returns a 401 error. Use when no valid credentials are present.
func Unauthorized() *Error {
	return &Error{
		HTTPStatus: http.StatusUnauthorized,
		Code:       CodeUnauthenticated,
		Message:    "authentication required",
	}
}

// Forbidden returns a 403 error. Use when credentials are valid but insufficient.
func Forbidden() *Error {
	return &Error{
		HTTPStatus: http.StatusForbidden,
		Code:       CodeForbidden,
		Message:    "you do not have permission to perform this action",
	}
}

// Validation returns a 422 error containing per-field validation messages.
func Validation(fieldErrors FieldErrors) *Error {
	return &Error{
		HTTPStatus:  http.StatusUnprocessableEntity,
		Code:        CodeValidationError,
		Message:     "request validation failed",
		FieldErrors: fieldErrors,
	}
}

// BadRequest returns a 400 error for a malformed request that is not a
// field-level validation failure (e.g. invalid JSON body, wrong Content-Type,
// unrecognised path parameter). For field-level failures use Validation().
func BadRequest(message string) *Error {
	return &Error{
		HTTPStatus: http.StatusBadRequest,
		Code:       CodeBadRequest,
		Message:    message,
	}
}

// Internal returns a 500 error. The internal cause is logged but never sent
// to the client; the public message is always generic.
func Internal(cause error) *Error {
	return &Error{
		HTTPStatus: http.StatusInternalServerError,
		Code:       CodeInternalError,
		Message:    "an unexpected error occurred",
		internal:   cause,
	}
}

// ServiceUnavailable returns a 503 error, typically used for degraded
// dependencies (database unavailable, RPC unreachable).
func ServiceUnavailable(cause error) *Error {
	return &Error{
		HTTPStatus: http.StatusServiceUnavailable,
		Code:       CodeServiceUnavailable,
		Message:    "service temporarily unavailable",
		internal:   cause,
	}
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// IsNotFound reports whether err is an *Error with a 404 status.
func IsNotFound(err error) bool {
	var e *Error
	return errors.As(err, &e) && e.HTTPStatus == http.StatusNotFound
}

// IsUnauthorized reports whether err is an *Error with a 401 status.
func IsUnauthorized(err error) bool {
	var e *Error
	return errors.As(err, &e) && e.HTTPStatus == http.StatusUnauthorized
}

// As attempts to unwrap err to *Error. Returns nil if err is not an *Error.
func As(err error) *Error {
	var e *Error
	if errors.As(err, &e) {
		return e
	}
	return nil
}
