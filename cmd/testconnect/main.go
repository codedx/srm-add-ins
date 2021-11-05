package main

import (
	"flag"
	"fmt"
	"github.com/codedx/codedx-add-ins/pkg/console"
	"net"
	"os"
	"time"
)

const (
	/* flag.go uses exit code 2 for invalid command-line arguments */
	invalidCommandLineArgumentsExitCode = 3
	unableToConnectExitCode             = 4
)

func main() {

	const hostFlagName = "host"
	const portFlagName = "port"
	const timeoutFlagName = "timeout"

	hostFlagValue := flag.String(hostFlagName, "localhost", "a path to the TOML file to convert to JSON")
	portFlagValue := flag.Int(portFlagName, 0, "a path to the JSON ouptut file")
	timeoutFlagValue := flag.Int(timeoutFlagName, 2, "a timeout in seconds")

	flag.Parse()

	host := console.ReadRequiredFlagStringValue(hostFlagName, hostFlagValue, invalidCommandLineArgumentsExitCode)
	port := console.ReadRequiredFlagNonNegativeIntValue(portFlagName, portFlagValue, invalidCommandLineArgumentsExitCode)
	timeout := console.ReadRequiredFlagNonNegativeIntValue(timeoutFlagName, timeoutFlagValue, invalidCommandLineArgumentsExitCode)

	timeoutTime := time.Now().Add(time.Second * time.Duration(timeout))
	for {
		conn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", host, port))
		if err != nil {
			if time.Now().Before(timeoutTime) {
				continue
			}
			os.Exit(unableToConnectExitCode)
		}
		_ = conn.Close()
		break
	}
}
