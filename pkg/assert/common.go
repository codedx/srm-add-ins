// Package assert provides functions to compare actual and expected test values.
package assert

import (
	"io/ioutil"
	"os"
	"runtime/debug"
	"strings"
	"testing"
)

// IntsAreEqual compares an expected int value and an actual int value for equality.
func IntsAreEqual(t *testing.T, expected int, actual int) {
	if expected != actual {
		debug.PrintStack()
		t.Fatalf("Expected: %d; Actual: %d", expected, actual)
	}
}

// Int32sAreEqual compares an expected int32 value and an actual int32 value for equality.
func Int32sAreEqual(t *testing.T, expected int32, actual int32) {
	if expected != actual {
		debug.PrintStack()
		t.Fatalf("Expected: %d; Actual: %d", expected, actual)
	}
}

// Int64sAreEqual compares an expected int64 value and an actual int64 value for equality.
func Int64sAreEqual(t *testing.T, expected int64, actual int64) {
	if expected != actual {
		debug.PrintStack()
		t.Fatalf("Expected: %d; Actual: %d", expected, actual)
	}
}

// StringPrefix compares an expected string value and an actual string value for a prefix match.
func StringPrefix(t *testing.T, expectedPrefix string, actual string) {
	if expectedPrefix == "" {
		t.FailNow() // invalid usage -> strings.HasPrefix will return true for empty string
	}

	if !strings.HasPrefix(actual, expectedPrefix) {
		debug.PrintStack()
		t.Fatalf("Actual does not start with expected: Expected: %s; Actual: %s", expectedPrefix, actual)
	}
}

// StringContains compares an expected string and an actual string value for a substring.
func StringContains(t *testing.T, expectedContains string, actual string) {
	if !strings.Contains(actual, expectedContains) {
		debug.PrintStack()
		t.Fatalf("Actual does not contain expected:\nExpected: %s\nActual: %s", expectedContains, actual)
	}
}

// StringNotContains compares an expected string and an actual string value for a missing substring.
func StringNotContains(t *testing.T, expectedNotContains string, actual string) {
	if strings.Contains(actual, expectedNotContains) {
		debug.PrintStack()
		t.Fatalf("Actual contains expected: Expected: %s; Actual: %s", expectedNotContains, actual)
	}
}

// StringsAreEqual compares an expected string value and an actual string value for equality.
func StringsAreEqual(t *testing.T, expected string, actual string) {
	if expected != actual {
		debug.PrintStack()

		if len(expected) <= 250 {
			t.Fatalf("\nExpected: %s;\nActual:   %s\n",
				expected,
				actual)
		} else {
			t.Fatalf("\nExpected: %s;\nActual:   %s\nExpected File: %s\nActual File:   %s\nDiff Cmd:      gvimdiff '%[3]s' '%[4]s'",
				expected,
				actual,
				saveString(expected, "expected-"),
				saveString(actual, "actual-"))
		}
	}
}

// EmptyString compares an actual string value and the empty string for equality.
func EmptyString(t *testing.T, actual string) {
	if actual != "" {
		debug.PrintStack()
		t.Fatalf("Expected empty string: Actual: %s", actual)
	}
}

// NotNil compares an interface and nil for equality.
func NotNil(t *testing.T, actual interface{}) {
	if actual == nil {
		debug.PrintStack()
		t.Fatal("Expected non-nil")
	}
}

// Nil compares an interface and nil for inequality.
func Nil(t *testing.T, actual interface{}) {
	if actual != nil {
		debug.PrintStack()
		t.Fatal("Expected nil")
	}
}

// NilError compares an error and nil.
func NilError(t *testing.T, err error) {
	if err != nil {
		debug.PrintStack()
		t.Fatalf("Expected nil error, found: %s", err.Error())
	}
}

// False compares a bool value to false.
func False(t *testing.T, actual bool) {
	if actual {
		debug.PrintStack()
		t.Fatalf("Expected false: Actual: %t", actual)
	}
}

// True compares a bool value to false.
func True(t *testing.T, actual bool) {
	if !actual {
		debug.PrintStack()
		t.Fatalf("Expected true: Actual: %t", actual)
	}
}

func saveString(str string, prefix string) string {
	f, _ := ioutil.TempFile(os.TempDir(), prefix)
	_, _ = f.WriteString(str)
	_ = f.Close()
	return f.Name()
}
