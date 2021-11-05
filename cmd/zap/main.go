package main

import (
	"bufio"
	"flag"
	"fmt"
	"github.com/codedx/codedx-add-ins/pkg/console"
	"github.com/codedx/codedx-add-ins/pkg/zap"
	zaproxy "github.com/zaproxy/zap-api-go/zap"
	"io"
	"io/ioutil"
	"log"
	"os"
	"sync"
	"time"
)

const (
	/* flag.go uses exit code 2 for invalid command-line arguments */
	cannotOpenLogFileExitCode                 = 3
	cannotOpenZapLogFileExitCode              = 4
	cannotOpenZapErrorLogFileExitCode         = 5
	cannotParseConfigurationFileExitCode      = 6
	missingXsltProgramExitCode                = 7
	zapAPINotReadyExitCode                    = 8
	createZapClientFailedExitCode             = 9
	createContextFailedExitCode               = 10
	anonymousSpiderFailedExitCode             = 11
	anonymousActiveScanFailedExitCode         = 12
	authenticatedUserSpiderFailedExitCode     = 13
	authenticatedUserActiveScanFailedExitCode = 14
	saveReportFailedExitCode                  = 15
	noNodesAddedExitCode                      = 16
)

func stopZap(quit chan int, wg *sync.WaitGroup) {

	select {
	case quit <- 0:
		log.Print("Sent quit message to ZAP")
	default:
		log.Print("Quit message not sent to ZAP")
	}

	log.Print("Waiting for ZAP to stop running...")
	wg.Wait()
	log.Print("ZAP stopped")
}

func exists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return true, err
}

func main() {

	const scanRequestFilePathFlagName = "scanRequestFile"

	logFile := flag.String("logFile", "log.log", "a path to the log file")
	zapStdoutLogFile := flag.String("zapStdoutLogFile", "zap.out.log", "a path to the ZAP stdout log file")
	zapStderrLogFile := flag.String("zapStderrLogFile", "zap.err.log", "a path to the ZAP stderr log file")

	scanRequestFilePathFlag := flag.String(scanRequestFilePathFlagName, "", "a path to the scan request file")

	zapPath := flag.String("zapPath", "zap.bat", "a path to the ZAP program")
	zapStartupWait := flag.Int("zapStartupWait", 450, "a duration in seconds for waiting on ZAP API availability")
	xsltProgram := flag.String("xsltProgram", "msxsl.exe", "a path to run XSLT using either msxsl or xsltproc")
	output := flag.String("output", "zap.output.xml", "a path to the ZAP report output file")

	flag.Parse()

	// tee to stdout for compatibility with `kubectl logs` command
	f := console.SetLogger("logFile", logFile, true, cannotOpenLogFileExitCode)
	defer func() {
		if err := f.Close(); err != nil {
			log.Println(err)
		}
	}()

	zapOut, err := os.OpenFile(*zapStdoutLogFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		console.Fatalf(cannotOpenZapLogFileExitCode, "Failed to open log file %s", *zapStdoutLogFile)
	}

	zapErr, err := os.OpenFile(*zapStderrLogFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		console.Fatalf(cannotOpenZapErrorLogFileExitCode, "Failed to open log file %s", *zapStderrLogFile)
	}

	defer func() {
		if err := zapOut.Close(); err != nil {
			log.Println(err)
		}
		if err := zapErr.Close(); err != nil {
			log.Println(err)
		}
	}()

	exists, err := exists(*xsltProgram)
	if !exists {
		errMsg := fmt.Sprintf("Unable to find xsltProgram at path %s", *xsltProgram)
		if err != nil {
			errMsg += " - " + err.Error()
		}
		console.Fatal(missingXsltProgramExitCode, errMsg)
	}

	sr := console.ReadFileFlagValue(scanRequestFilePathFlagName, scanRequestFilePathFlag, true, cannotParseConfigurationFileExitCode)
	config, err := zap.ParseConfig(sr)
	if err != nil {
		console.Fatal(cannotParseConfigurationFileExitCode, err)
	}

	var wg sync.WaitGroup

	apiKey := "api-key"
	quit := make(chan int)     // channel to keep zap go routine running until it's time to quit ZAP
	ready := make(chan string) // channel to wait for zap initialization

	wg.Add(1)
	go zap.RunZap(*zapPath, apiKey, time.Second*time.Duration(*zapStartupWait), io.MultiWriter(os.Stdout, zapOut), io.MultiWriter(os.Stderr, zapErr), ready, quit, &wg)

	version, ok := <-ready
	if !ok {
		stopZap(quit, &wg)
		console.Fatal(zapAPINotReadyExitCode, "ZAP is not ready. Exiting...")
	}
	log.Printf("ZAP API version %s is ready", version)

	client, err := zap.MakeClient(apiKey)
	if err != nil {
		stopZap(quit, &wg)
		console.Fatalf(createZapClientFailedExitCode, "Unable to create new ZAP client with API key %s", apiKey)
	}

	ctx := createContext(client, config, quit, &wg)

	nodeCnt := runAnonymousSpider(client, config, quit, &wg)

	runAnonymousScan(client, config, ctx, quit, &wg)

	nodeCnt += runSpiderAndScan(client, config, ctx, quit, &wg)

	if nodeCnt == 0 {
		console.Fatalf(noNodesAddedExitCode, "Spider operation(s) added 0 nodes. Is the target URL set correctly?")
	}

	saveReport(client, config, xsltProgram, output, quit, &wg)

	log.Println("Stopping ZAP...")
	stopZap(quit, &wg)

	log.Println("ZAP scan completed")
}

func createContext(client *zaproxy.Interface, config *zap.Config, quit chan int, wg *sync.WaitGroup) *zap.Context {

	log.Println("Creating context...")
	ctx, err := zap.ConfigureContext(client, config)
	if err != nil {
		stopZap(quit, wg)
		console.Fatal(createContextFailedExitCode, err)
	}

	if len(config.Context.ImportURLs) > 0 {

		log.Println("Importing URLs...")
		file, err := ioutil.TempFile("", "urls")
		if err != nil {
			console.Fatal(createContextFailedExitCode, err)
		}
		defer func() {
			if err := os.Remove(file.Name()); err != nil {
				log.Println(err)
			}
		}()

		writer := bufio.NewWriter(file)
		for _, data := range config.Context.ImportURLs {
			_, _ = writer.WriteString(data + "\n")
		}

		if err := writer.Flush(); err != nil {
			console.Fatal(createContextFailedExitCode, err)
		}
		if err := file.Close(); err != nil {
			console.Fatal(createContextFailedExitCode, err)
		}

		if _, err := (*client).Importurls().Importurls(file.Name()); err != nil {
			console.Fatal(createContextFailedExitCode, err)
		}
	}

	log.Printf("Established context with ID %s", ctx.ContextID)
	return &ctx
}

func runAnonymousSpider(client *zaproxy.Interface, config *zap.Config, quit chan int, wg *sync.WaitGroup) int {

	log.Println("Starting spider (anonymous)...")
	cnt, err := zap.Spider(client, config.Context.Target, config.Context.Name)
	if err != nil {
		stopZap(quit, wg)
		console.Fatal(anonymousSpiderFailedExitCode, err)
	}
	log.Printf("Spider completed - add %d node(s)", cnt)
	return cnt
}

func runAnonymousScan(client *zaproxy.Interface, config *zap.Config, ctx *zap.Context, quit chan int, wg *sync.WaitGroup) {

	if !config.ScanOptions.RunActiveScan {
		return
	}

	log.Println("Starting scan (anonymous)...")
	if err := zap.Scan(client, config.Context.Target, ctx.ContextID); err != nil {
		stopZap(quit, wg)
		console.Fatal(anonymousActiveScanFailedExitCode, err)
	}
	log.Println("Scan completed")
}

func runSpiderAndScan(client *zaproxy.Interface, config *zap.Config, ctx *zap.Context, quit chan int, wg *sync.WaitGroup) int {

	totalCnt := 0
	log.Println("Starting spider and scan...")
	for i := range ctx.Users {
		user := ctx.Users[i]

		if config.Authentication.ForcedUserMode {
			log.Printf("Forcing user (%s)...", user.Credential.Username)
			if err := zap.ForceUser(client, ctx.ContextID, user.UserID); err != nil {
				console.Fatal(authenticatedUserSpiderFailedExitCode, err)
			}
		}

		log.Printf("Starting spider (%s)...", user.Credential.Username)
		cnt, err := zap.SpiderAsUser(client, config.Context.Target, ctx.ContextID, user.UserID)
		if err != nil {
			stopZap(quit, wg)
			console.Fatal(authenticatedUserSpiderFailedExitCode, err)
		}
		log.Printf("Spider completed - add %d node(s)", cnt)

		totalCnt += cnt

		if !config.ScanOptions.RunActiveScan {
			continue
		}

		log.Printf("Starting scan (%s)...", user.Credential.Username)
		if err := zap.ScanAsUser(client, config.Context.Target, ctx.ContextID, user.UserID); err != nil {
			stopZap(quit, wg)
			console.Fatal(authenticatedUserActiveScanFailedExitCode, err)
		}
		log.Println("Scan completed")
	}
	log.Println("Spider and scan completed")
	return totalCnt
}

func saveReport(client *zaproxy.Interface, config *zap.Config, xsltProgram *string, output *string, quit chan int, wg *sync.WaitGroup) {

	log.Println("Saving report...")
	if err := zap.SaveReport(client, *xsltProgram, *output,
		config.ReportOptions.MinRiskThreshold, config.ReportOptions.MinConfThreshold); err != nil {
		stopZap(quit, wg)
		console.Fatal(saveReportFailedExitCode, err)
	}
	log.Println("Report saved")
}
