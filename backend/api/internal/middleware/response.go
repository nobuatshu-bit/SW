package middleware

import "github.com/sherwood-labs/sherwood/backend/api/pkg/apierr"

// errorBody is the JSON shape for all error responses.
// Kept unexported; serialised only through errorResponse.
type errorBody struct {
	Success bool        `json:"success"`
	Error   errorDetail `json:"error"`
}

type errorDetail struct {
	Code        apierr.Code        `json:"code"`
	Message     string             `json:"message"`
	FieldErrors apierr.FieldErrors `json:"field_errors,omitempty"`
}

// errorResponse converts an *apierr.Error into the standard JSON envelope.
// Used by Recovery, Auth, and any handler that calls c.AbortWithStatusJSON.
func errorResponse(e *apierr.Error) errorBody {
	return errorBody{
		Success: false,
		Error: errorDetail{
			Code:        e.Code,
			Message:     e.Message,
			FieldErrors: e.FieldErrors,
		},
	}
}
