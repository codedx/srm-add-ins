package zap

import (
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
	ImportURLs                []string
	IncludeRegularExpressions []string
	ExcludeRegularExpressions []string
}

type reportOptions struct {
	MinRiskThreshold int
	MinConfThreshold int
}

type scanOptions struct {
	RunActiveScan bool
}

type authentication struct {
	Type                string
	LoginIndicatorRegex string
	ForcedUserMode      bool
}

// Credentials contains the usernames/passwords to use for spiders/scans.
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

// Config holds the configuration describing how to run the ZAP tool.
type Config struct {
	Request              request
	Context              context
	ReportOptions        reportOptions
	ScanOptions          scanOptions
	Authentication       authentication
	FormAuthentication   formAuthentication
	ScriptAuthentication scriptAuthentication
	credentials          Credentials // reading credentials from TOML file is unsupported - use SecretsToMount instead
}

func (c *Config) useFormAuthentication() bool {
	return c.Authentication.Type == "formAuthentication"
}

func (c *Config) useScriptAuthentication() bool {
	return c.Authentication.Type == "scriptAuthentication"
}

func (c *Config) isAuthenticationEnabled() bool {
	return (c.useFormAuthentication() || c.useScriptAuthentication()) && c.credentials != nil && len(c.credentials) > 0
}

func (c *Config) isValid() bool {
	return c.Context.Name != "" && c.Context.Target != ""
}

// GetCredentials returns a list of ZAP user credentials loaded via a scan request file.
func (c *Config) GetCredentials() Credentials {
	return c.credentials
}

// ParseConfig reads configuration data from a request file in either the current directory or the config subdirectory.
func ParseConfig(configFilePath string) (*Config, error) {

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

	applyDefaults(&cfg)

	if err := loadCredentials(&cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

func applyDefaults(config *Config) {

	if config.Context.Name == "" {
		config.Context.Name = "Context"
	}

	if len(config.Context.IncludeRegularExpressions) == 0 {
		config.Context.IncludeRegularExpressions = append(config.Context.IncludeRegularExpressions, config.Context.Target+".*")
	}
}

func loadCredentials(config *Config) error {

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

		u, err := ioutil.ReadFile(filepath.FromSlash(path.Join(filePath, "username")))
		if err != nil {
			return err
		}
		p, err := ioutil.ReadFile(filepath.FromSlash(path.Join(filePath, "password")))
		if err != nil {
			return err
		}
		config.credentials = append(config.credentials, Credential{
			Username: strings.TrimSpace(string(u)),
			Password: strings.TrimSpace(string(p)),
		})
		return filepath.SkipDir
	})
}
