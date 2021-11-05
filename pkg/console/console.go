// Package console contains helper functions for ending a program with a specific exit code and message.
package console

import (
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/url"
	"os"
	"strings"
)

// Fatal terminates a program with a specific exit code and zero or more messages.
func Fatal(exitCode int, v ...interface{}) {
	log.Print(v...)
	log.Printf("Program exiting with exit code %d", exitCode)
	os.Exit(exitCode)
}

// Fatalf terminates a program with a specific exit code and zero or more messages
// formatted using a format string that's sent to the log and stderr.
func Fatalf(exitCode int, format string, v ...interface{}) {
	log.Printf(format, v...)
	fmt.Fprintf(os.Stderr, format, v...)
	os.Exit(exitCode)
}

// SetLogger sets the output destination for the standard logger to the specified file flag value.
// It returns the log file and ends the program with the specified exit code if an error occurs.
func SetLogger(flagName string, flagValue *string, teeToStdout bool, onErrorExitCode int) *os.File {

	if flagValue == nil || *flagValue == "" {
		Fatalf(onErrorExitCode, "Flag %s should be a log file path", flagName)
	}

	f, err := os.OpenFile(*flagValue, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		Fatalf(onErrorExitCode, "Failed to open log file %s: %s", *flagValue, err.Error())
	}

	if teeToStdout {
		log.SetOutput(io.MultiWriter(os.Stdout, f))
	} else {
		log.SetOutput(f)
	}

	return f
}

// ReadTextFileFlagValue returns the string in the specified file flag value.
// It returns the file contents as a trimmed string value and ends the program with the specified exit code
// if an error occurs.
func ReadTextFileFlagValue(flagName string, flagValue *string, isRequired bool, onErrorExitCode int) string {

	if flagValue == nil || *flagValue == "" {
		if !isRequired {
			return ""
		}
		Fatalf(onErrorExitCode, "Flag %s should be a path to a file containing text", flagName)
	}

	b, err := ioutil.ReadFile(*flagValue)
	if err != nil {
		Fatal(onErrorExitCode, err)
	}

	v := strings.TrimSpace(string(b))
	if isRequired && v == "" {
		Fatalf(onErrorExitCode, "Required string in file %s is missing", *flagValue)
	}

	return v
}

// ReadFileFlagValue tests whether the specified string refers to a file.
// It ends the program with the specified exit code if an error occurs or if the required file flag value
// does not refer to a file.
func ReadFileFlagValue(flagName string, flagValue *string, isRequired bool, onErrorExitCode int) string {

	if flagValue == nil || *flagValue == "" {
		if !isRequired {
			return ""
		}
		Fatalf(onErrorExitCode, "Flag %s should be a file", flagName)
	}

	i, err := os.Stat(*flagValue)
	if err != nil {
		Fatalf(onErrorExitCode, "Unable to interpret file %s", *flagValue)
	}

	if !i.Mode().IsRegular() {
		Fatalf(onErrorExitCode, "%s is not a file", *flagValue)
	}
	return *flagValue
}

// ReadDirectoryFlagValue tests whether the specified string refers to a directory.
// It ends the program with the specified exit code if an error occurs or if the required directory flag value
// does not refer to a directory.
func ReadDirectoryFlagValue(flagName string, flagValue *string, isRequired bool, onErrorExitCode int) string {

	if flagValue == nil || *flagValue == "" {
		if !isRequired {
			return ""
		}
		Fatalf(onErrorExitCode, "Flag %s should be a directory", flagName)
	}

	i, err := os.Stat(*flagValue)
	if err != nil {
		Fatalf(onErrorExitCode, "Unable to interpret directory %s", *flagValue)
	}

	if !i.Mode().IsDir() {
		Fatalf(onErrorExitCode, "%s is not a directory", *flagValue)
	}
	return *flagValue
}

// ReadRequiredFlagStringValue returns the value of a required string flag.
// It returns the flag value for the specified flag and ends the program with the specified exit code if the
// flag value is not present.
func ReadRequiredFlagStringValue(flagName string, flagValue *string, onErrorExitCode int) string {

	if flagValue == nil || *flagValue == "" {
		Fatalf(onErrorExitCode, "Flag %s is required", flagName)
	}
	return *flagValue
}

// ReadRequiredFlagNonNegativeIntValue returns the value of a required int flag.
// It returns the flag value for the specified flag and ends the program with the specified exit code if the
// flag value is negative.
func ReadRequiredFlagNonNegativeIntValue(flagName string, flagValue *int, onErrorExitCode int) int {

	if flagValue == nil {
		Fatalf(onErrorExitCode, "Flag %s is required", flagName)
		return 0 // Fatalf will os.exit - this line silences linter
	}

	if *flagValue < 0 {
		Fatalf(onErrorExitCode, "%d must be >= 0", *flagValue)
	}

	return *flagValue
}

// ReadRequiredFlagBoolValue returns the value of a required bool flag.
// It returns the flag value for the specified flag and ends the program with the specified exit code if the
// flag value is missing.
func ReadRequiredFlagBoolValue(flagName string, flagValue *bool, onErrorExitCode int) bool {

	if flagValue == nil {
		Fatalf(onErrorExitCode, "Flag %s is required", flagName)
		return false // Fatalf will os.exit - this line silences linter
	}

	return *flagValue
}

// ReadRequiredFlagBaseURLValue returns the value of a required base URL flag.
// It returns the flag value for the specified flag and ends the program with the specified exit code if the
// flag value is not a valid URL.
func ReadRequiredFlagBaseURLValue(flagName string, flagValue *string, onErrorExitCode int) url.URL {

	if flagValue == nil {
		Fatalf(onErrorExitCode, "Flag %s is required", flagName)
		return url.URL{} // Fatalf will os.exit - this line silences linter
	}

	u, err := url.ParseRequestURI(*flagValue)
	if err != nil || strings.HasSuffix(u.Path, "/") {
		Fatalf(onErrorExitCode, "Flag for base URL %s is invalid (specify scheme://host[:port])", flagName)
	}
	return *u
}

// ReadStringCollectionValue returns the value of a string collection flag.
// It returns the collection of values expressed with a semicolon separator character.
func ReadStringCollectionValue(flagValue *string) []string {
	return ReadStringCollectionWithSeparatorValue(flagValue, ";")
}

// ReadStringCollectionWithSeparatorValue returns the value of a string collection flag.
// It returns the collection of values expressed using the specified separator character.
func ReadStringCollectionWithSeparatorValue(flagValue *string, sep string) []string {

	if flagValue == nil {
		return make([]string, 0)
	}

	s := strings.Split(*flagValue, sep)

	c := make([]string, 0)
	for _, i := range s {
		if i == "" {
			continue
		}
		c = append(c, strings.TrimSpace(i))
	}
	return c
}
