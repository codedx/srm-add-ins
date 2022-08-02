package zap

import (
	"errors"
	"github.com/spf13/viper"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"strings"
)

type request struct {
	Name           string
	SecretsToMount []string
	WorkDirectory  string
}

func (r *request) GetWorkflowSecretsDirectory() string {
	return filepath.ToSlash(filepath.Join(r.WorkDirectory, "workflow-secrets"))
}

type context struct {
	Name                      string
	Target                    string
	Format                    string // api scan only
	OpenApiHostnameOverride   string // api scan only
	ImportURLs                []string // normal scan only
	IncludeRegularExpressions []string
	ExcludeRegularExpressions []string
}

type reportOptions struct {
	MinRiskThreshold int
	MinConfThreshold int
}

type scanOptions struct {
	RunActiveScan        bool
	ApiScanOptions       []string // api scan only
	ApiScanConfigContent string // api scan only
}

type authentication struct {
	Type                string
	LoginIndicatorRegex string
	ForcedUserMode      bool // normal scan only
}

// Credentials contains the usernames/passwords to use for spiders/scans.
// api scans can have at most one credential.
type Credentials []Credential

// Credential contains a user credential to use for a spider/scan.
type Credential struct {
	Username string
	Password string
}

type formAuthentication struct {
	FormURL                                  string
	FormUsernameFieldName                    string
	FormPasswordFieldName                    string
	FormAntiCrossSiteRequestForgeryFieldName string
	FormExtraPostData                        string
}

type scriptAuthentication struct {
	AuthenticationScriptContent string
}

// api scan only
type headerAuthentication struct {
	AuthHeaderName string
	AuthHeaderSite string
}

// Config holds the configuration describing how to run the ZAP tool.
type Config struct {
	Request              request
	Context              context
	ReportOptions        reportOptions
	ScanOptions          scanOptions
	Authentication       authentication
	FormAuthentication   formAuthentication
	ScriptAuthentication scriptAuthentication
	HeaderAuthentication headerAuthentication // api scan only
	credentials          Credentials // reading credentials from TOML file is unsupported - use SecretsToMount instead
}

func (c *Config) UseFormAuthentication() bool {
	return c.Authentication.Type == "formAuthentication"
}

func (c *Config) UseScriptAuthentication() bool {
	return c.Authentication.Type == "scriptAuthentication"
}

func (c *Config) UseHeaderAuthentication() bool {
	return c.Authentication.Type == "headerAuthentication"
}

func (c *Config) IsAuthenticationEnabled() bool {
	return (c.UseFormAuthentication() || c.UseScriptAuthentication() || c.UseHeaderAuthentication()) && c.credentials != nil && len(c.credentials) > 0
}

func (c *Config) IsContextAuthRequired() bool {
	return c.IsAuthenticationEnabled() && (c.UseScriptAuthentication() || c.UseFormAuthentication())
}

func (c *Config) IsContextFileRequired() bool {
	return len(c.Context.IncludeRegularExpressions) > 0 || len(c.Context.ExcludeRegularExpressions) > 0 || c.IsContextAuthRequired()
}

func (c *Config) IsValid(scanMode string) bool {
	if c.Context.Name == "" || c.Context.Target == "" {
		return false
	}
	if IsNormalScan(scanMode) {
		// disallow api-scan only fields
		return c.Context.Format == "" &&
			c.Context.OpenApiHostnameOverride == "" &&
			len(c.ScanOptions.ApiScanOptions) == 0 &&
			c.ScanOptions.ApiScanConfigContent == "" &&
			!c.UseHeaderAuthentication()
	} else if IsApiScan(scanMode) {
		// require format be defined and disallow normal-scan only fields
		return c.Context.Format != "" && !c.Authentication.ForcedUserMode && len(c.Context.ImportURLs) == 0
	}
	return false
}

// GetCredentials returns a list of ZAP user credentials loaded via a scan request file.
func (c *Config) GetCredentials() Credentials {
	return c.credentials
}

func IsApiScan(scanMode string) bool {
	return scanMode == "api"
}

func IsNormalScan(scanMode string) bool {
	return scanMode == "normal"
}

// ParseConfig reads configuration data from a request file in either the current directory or the config subdirectory.
func ParseConfig(configFilePath string, scanMode string) (*Config, error) {

	dir, filename := filepath.Split(configFilePath)
	extension := filepath.Ext(filename)
	filenameNoExtension := filename[0 : len(filename)-len(extension)]

	var cfg Config
	viper.SetConfigName(filenameNoExtension)
	viper.AddConfigPath(dir)
	err := viper.ReadInConfig()
	if err != nil {
		return nil, err
	}
	if err = viper.Unmarshal(&cfg); err != nil {
		return nil, err
	}

	applyDefaults(&cfg, scanMode)

	if err := loadCredentials(&cfg, scanMode); err != nil {
		return nil, err
	}

	return &cfg, nil
}

func applyDefaults(config *Config, scanMode string) {

	if config.Context.Name == "" {
		config.Context.Name = "Context"
	}

	if len(config.Context.IncludeRegularExpressions) == 0 && IsNormalScan(scanMode) {
		config.Context.IncludeRegularExpressions = append(config.Context.IncludeRegularExpressions, config.Context.Target+".*")
	}
}

func loadCredentials(config *Config, scanMode string) error {

	credentialsDirectory := config.Request.GetWorkflowSecretsDirectory()
	if credentialsDirectory == "" {
		return nil
	}

	if config.credentials == nil {
		config.credentials = make([]Credential, 0)
	}

	return filepath.Walk(credentialsDirectory, func(filePath string, info os.FileInfo, e error) error {

		if filePath == credentialsDirectory || !info.IsDir() {
			return nil
		}

		if IsApiScan(scanMode) && len(config.credentials) > 0 {
			return errors.New("only one credential can be defined")
		}

		user := ""
		pass := ""

		if config.UseHeaderAuthentication() {
			var err error
			p, err := ioutil.ReadFile(filepath.FromSlash(path.Join(filePath, "header-value")))
			if err != nil {
				return err
			}
			pass = string(p)
		} else {
			u, err := ioutil.ReadFile(filepath.FromSlash(path.Join(filePath, "username")))
			if err != nil {
				return err
			}
			p, err := ioutil.ReadFile(filepath.FromSlash(path.Join(filePath, "password")))
			if err != nil {
				return err
			}
			user = string(u)
			pass = string(p)
		}
		config.credentials = append(config.credentials, Credential{
			Username: strings.TrimSpace(user),
			Password: strings.TrimSpace(pass),
		})
		return filepath.SkipDir
	})
}
