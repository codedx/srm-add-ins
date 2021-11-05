package assert

import (
	"net/http/httptest"
	"testing"
)

// StatusCode compares an expected status code and a response status code for equality.
func StatusCode(t *testing.T, expected int, rr *httptest.ResponseRecorder) {
	IntsAreEqual(t, expected, rr.Code)
}

// BodyPrefix compares an expected string and a response body for a prefix match.
func BodyPrefix(t *testing.T, expected string, rr *httptest.ResponseRecorder) {
	StringPrefix(t, expected, rr.Body.String())
}

// Body compares an expected string and a response body for equality.
func Body(t *testing.T, expected string, rr *httptest.ResponseRecorder) {
	StringsAreEqual(t, expected, rr.Body.String())
}
