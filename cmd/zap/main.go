package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"github.com/codedx/codedx-add-ins/pkg/console"
	"github.com/codedx/codedx-add-ins/pkg/zap"
	zaproxy "github.com/zaproxy/zap-api-go/zap"
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
	invalidConfigurationExitCode              = 17
	apiScanAuthScriptErrorExitCode            = 18
	apiScanConfigFileErrorExitCode            = 19
	apiScanFailedExitCode                     = 20
	copyReportFailedExitCode                  = 21
	applyXsltFailedExitCode                   = 22
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
	const zapApiScanPathFlagName = "zapApiScanPath"
	const zapWorkDirFlagName = "zapWorkDir"

	logFile := flag.String("logFile", "log.log", "a path to the log file")
	zapStdoutLogFile := flag.String("zapStdoutLogFile", "zap.out.log", "a path to the ZAP stdout log file")
	zapStderrLogFile := flag.String("zapStderrLogFile", "zap.err.log", "a path to the ZAP stderr log file")

	scanRequestFilePathFlag := flag.String(scanRequestFilePathFlagName, "", "a path to the scan request file")

	zapPath := flag.String("zapPath", "zap.bat", "a path to the ZAP program")
	zapStartupWait := flag.Int("zapStartupWait", 450, "a duration in seconds for waiting on ZAP API availability")
	xsltProgram := flag.String("xsltProgram", "msxsl.exe", "a path to run XSLT using either msxsl or xsltproc")
	output := flag.String("output", "zap.output.xml", "a path to the ZAP report output file")
	scanMode := flag.String("scanMode", "normal", "the type of scan to run; normal or api")

	zapApiScanPathFlag := flag.String(zapApiScanPathFlagName, "/zap/zap-api-scan.py", "a path to the ZAP API scan Python script")
	zapWorkDirFlag := flag.String(zapWorkDirFlagName, "/zap/wrk", "a path to the ZAP working directory")

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

	zapApiScanPath := console.ReadFileFlagValue(zapApiScanPathFlagName, zapApiScanPathFlag, true, cannotParseConfigurationFileExitCode)
	zapWorkDir := console.ReadDirectoryFlagValue(zapWorkDirFlagName, zapWorkDirFlag, true, cannotParseConfigurationFileExitCode)

	config, err := zap.ParseConfig(sr, *scanMode)
	if err != nil {
		console.Fatal(cannotParseConfigurationFileExitCode, err)
	}
	if !config.IsValid(*scanMode) {
		console.Fatal(invalidConfigurationExitCode, "cannot configure context because ZAP configuration is invalid")
	}

	if zap.IsNormalScan(*scanMode) {
		runScan(zapPath, zapStartupWait, zapOut, zapErr, config, xsltProgram, output)
	} else {
		runApiScan(zapApiScanPath, zapWorkDir, zapPath, zapStartupWait, zapOut, zapErr, config, xsltProgram, output)
	}
}

func initZap(zapPath *string, zapStartupWait *int, outWriter io.Writer, errWriter io.Writer, wg *sync.WaitGroup) (*zaproxy.Interface, chan int) {
	apiKey := "api-key"
	quit := make(chan int)     // channel to keep zap go routine running until it's time to quit ZAP
	ready := make(chan string) // channel to wait for zap initialization

	wg.Add(1)
	go zap.RunZap(*zapPath, apiKey, time.Second*time.Duration(*zapStartupWait), outWriter, errWriter, ready, quit, wg)

	version, ok := <-ready
	if !ok {
		stopZap(quit, wg)
		console.Fatal(zapAPINotReadyExitCode, "ZAP is not ready. Exiting...")
	}
	log.Printf("ZAP API version %s is ready", version)

	client, err := zap.MakeClient(apiKey)
	if err != nil {
		stopZap(quit, wg)
		console.Fatalf(createZapClientFailedExitCode, "Unable to create new ZAP client with API key %s", apiKey)
	}
	return client, quit
}

func runScan(zapPath *string, zapStartupWait *int, zapOut *os.File, zapErr *os.File, config *zap.Config, xsltProgram *string, output *string) {
	var wg sync.WaitGroup

	client, quit := initZap(zapPath, zapStartupWait, io.MultiWriter(os.Stdout, zapOut), io.MultiWriter(os.Stderr, zapErr), &wg)

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
	ctx, err := zap.ConfigureContext(client, config, "")
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

func runApiScan(zapApiScanPath string, zapWorkDir string, zapPath *string, zapStartupWait *int, zapOut *os.File, zapErr *os.File, config *zap.Config, xsltProgram *string, output *string) {
	// The current ZAP release (2.11.1) requires some of the file path args to be given relative to
	// the /zap/wrk/ dir. Of the arguments that runApiScan uses, this includes the context file (-n),
	// config file (-c), and report output file (-x). Future releases of ZAP will not have this
	// limitation and will allow fully qualified paths, including paths outside of the /zap/wrk/ dir.
	reportFile := filepath.Join(zapWorkDir, "report.xml")
	reportFileArg := "report.xml"
	apiScanArgs := []string{
		zapApiScanPath,
		"-t", config.Context.Target,
		"-f", config.Context.Format,
		"-x", reportFileArg,
	}

	if config.IsContextFileRequired() {
		contextFile := filepath.Join(zapWorkDir, "context.xml")
		contextFileArg := "context.xml"

		// this file name/location corresponds to the one in auth_script_hook.py
		authScriptFile := filepath.Join(zapWorkDir, "authScript")
		authHooksFile := filepath.Join(zapWorkDir, "auth_script_hook.py")

		ctx := createApiScanContextFile(contextFile, authScriptFile, zapPath, zapStartupWait, config)
		if config.IsContextAuthRequired() {
			if config.UseScriptAuthentication() {
				// make sure the authScript was created
				authExists, err := exists(authScriptFile)
				if !authExists {
					errMsg := "authScript does not exist"
					if err != nil {
						errMsg += " - " + err.Error()
					}
					console.Fatal(apiScanAuthScriptErrorExitCode, errMsg)
				}
				// add the auth_script_hook, which loads the authScript in the api-scan ZAP daemon after it starts
				apiScanArgs = append(apiScanArgs, "--hook", authHooksFile)
			}
			apiScanArgs = append(apiScanArgs, "-U", ctx.Users[0].Credential.Username)
		}
		apiScanArgs = append(apiScanArgs, "-n", contextFileArg)
	}

	if config.Context.OpenApiHostnameOverride != "" {
		apiScanArgs = append(apiScanArgs, "-O", config.Context.OpenApiHostnameOverride)
	}

	if !config.ScanOptions.RunActiveScan {
		apiScanArgs = append(apiScanArgs, "-S")
	}

	if config.ScanOptions.ApiScanConfigContent != "" {
		configFile := filepath.Join(zapWorkDir, "config.txt")
		configFileArg := "config.txt"
		err := writeConfigFile(configFile, config.ScanOptions.ApiScanConfigContent)
		if err != nil {
			console.Fatal(apiScanConfigFileErrorExitCode, "Unable to write ZAP API scan config file")
		}
		apiScanArgs = append(apiScanArgs, "-c", configFileArg)
	}

	// for backward compatibility with zap container image v1.52.0 and earlier, rely on the PATH environment variable for the
	// location of python3, which will be either the global python (/usr/bin/python) used with v1.52.0 and earlier or the
	// one in a virtual environment (at /opt/python/bin/python3) required for v1.53.0 and later
	cmd := exec.Command(
		"python3", append(apiScanArgs, config.ScanOptions.ApiScanOptions...)...,
	)
	cmd.Stdout = io.MultiWriter(os.Stdout, zapOut)
	cmd.Stderr = io.MultiWriter(os.Stderr, zapErr)

	if config.IsAuthenticationEnabled() && config.UseHeaderAuthentication() {
		env := fmt.Sprintf("ZAP_AUTH_HEADER_VALUE=%s", config.GetCredentials()[0].Password)
		cmd.Env = append(os.Environ(), env)
		if config.HeaderAuthentication.AuthHeaderName != "" {
			env = fmt.Sprintf("ZAP_AUTH_HEADER=%s", config.HeaderAuthentication.AuthHeaderName)
			cmd.Env = append(cmd.Env, env)
		}
		if config.HeaderAuthentication.AuthHeaderSite != "" {
			env = fmt.Sprintf("ZAP_AUTH_HEADER_SITE=%s", config.HeaderAuthentication.AuthHeaderSite)
			cmd.Env = append(cmd.Env, env)
		}
	}

	log.Println("Starting scan (API)...")

	err := cmd.Run()
	if err != nil {
		exitErr, _ := err.(*exec.ExitError)
		exitCode := exitErr.ExitCode()
		// allow 1 and 2, which indicate there are errors/failures
		if exitCode > 2 || exitCode < 0 {
			console.Fatal(apiScanFailedExitCode, err)
		}
	}

	log.Println("Scan completed")

	// copy the report from /zap/wrk/report.xml to the specified output file - we cannot move
	// the file because the destination file will be a different filesystem when the root filesystem
	// is read-only
	err = copyFile(reportFile, *output)
	if err != nil {
		console.Fatal(copyReportFailedExitCode, err)
	}

	log.Println("Applying report template...")
	err = zap.ApplyXslt(*xsltProgram, *output, config.ReportOptions.MinRiskThreshold, config.ReportOptions.MinConfThreshold)
	if err != nil {
		console.Fatal(applyXsltFailedExitCode, err)
	}
	log.Println("Teport template applied")
}

func copyFile(srcPath string, destPath string) error {

	src, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := src.Close(); err != nil {
			log.Printf("Unable to close file %s", srcPath)
		}
	}()

	dest, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := dest.Close(); err != nil {
			log.Printf("Unable to close file %s", destPath)
		}
	}()

	if _, err = io.Copy(dest, src); err != nil {
		return err
	}
	return nil
}

// launch and configure a ZAP instance, then export the context file and shut it down
func createApiScanContextFile(contextFile string, authScriptFile string, zapPath *string, zapStartupWait *int, config *zap.Config) zap.Context {
	log.Println("Creating ZAP context file")

	var wg sync.WaitGroup

	client, quit := initZap(zapPath, zapStartupWait, ioutil.Discard, ioutil.Discard, &wg)

	log.Println("Creating context...")
	ctx, err := zap.ConfigureContext(client, config, authScriptFile)
	if err != nil {
		stopZap(quit, &wg)
		console.Fatal(createContextFailedExitCode, err)
	}

	_, err = (*client).Context().ExportContext(ctx.ContextName, contextFile)
	if err != nil {
		stopZap(quit, &wg)
		console.Fatal(createContextFailedExitCode, err)
	}

	log.Println("Stopping ZAP...")
	stopZap(quit, &wg)

	log.Println("ZAP context file created")

	return ctx
}

func writeConfigFile(configFile string, configText string) error {
	f, err := os.Create(configFile)
	if err != nil {
		return err
	}

	_, err = f.WriteString(configText)
	if err != nil {
		if err := f.Close(); err != nil {
			log.Println(err)
		}
		return err
	}

	err = f.Close()
	if err != nil {
		return err
	}

	return nil
}
