Set-PSDebug -Strict
$ErrorActionPreference = 'Stop'

function Get-SecurityCodeScanRules() {
    $header = 'code','category','cweid','cweid-inferred','name','severity','url','description'
    $rules = 'SCS0001,Injection,78,,Command injection possible in passed argument,high,https://security-code-scan.github.io/#SCS0001,The dynamic value passed to the command execution should be validated.',
    'SCS0002,SQL Injection,89,,LINQ API: SQL injection possible,high,https://security-code-scan.github.io/#SCS0002,The dynamic value passed in the SQL query should be validated.',
    'SCS0003,Injection,643,,XPath injection possible in passed argument,high,https://security-code-scan.github.io/#SCS0003,The dynamic value passed to the XPath query should be validated',
    'SCS0004,Cryptography,295,,Certificate Validation has been disabled,unspecified,https://security-code-scan.github.io/#SCS0004,Certificate Validation has been disabled. The communication could be intercepted.',
    'SCS0005,Cryptography,338,,Weak random generator,medium,https://security-code-scan.github.io/#SCS0005,The random numbers generated could be predicted.',
    'SCS0006,Cryptography,?,,Weak hashing function,unspecified,https://security-code-scan.github.io/#SCS0006,MD5 is no longer considered a strong hashing algorithm.',
    'SCS0007,Injection,611,,XML parsing vulnerable to XXE,unspecified,https://security-code-scan.github.io/#SCS0007,The XML parser is configured incorrectly. The operation could be vulnerable to XML eXternal Entity (XXE) processing.',
    'SCS0008,Cookies,315,,The cookie is missing security flag Secure,unspecified,https://security-code-scan.github.io/#SCS0008,It is recommended to specify the Secure flag to new cookie.',
    'SCS0009,Cookies,1004,Y,The cookie is missing security flag HttpOnly,medium,https://security-code-scan.github.io/#SCS0009,It is recommended to specify the HttpOnly flag to new cookie.',
    'SCS0010,Cryptography,326,,Weak cipher algorithm,unspecified,https://security-code-scan.github.io/#SCS0010,DES and 3DES are not considered a strong cipher for modern applications. NIST recommends the usage of AES block ciphers instead.',
    'SCS0011,Cryptography,696,,CBC mode is weak,unspecified,https://security-code-scan.github.io/#SCS0011,This specific mode of CBC with PKCS5Padding is susceptible to padding oracle attacks. An adversary could potentially decrypt the message if the system exposed the difference between plaintext with invalid padding or valid padding.',
    'SCS0012,Cryptography,696,,ECB mode is weak,unspecified,https://security-code-scan.github.io/#SCS0012,ECB mode will produce the same result for identical blocks (i.e.: 16 bytes for AES). An attacker could be able to guess the encrypted message. The use of AES in CBC mode with a HMAC is recommended guaranteeing integrity and confidentiality.',
    'SCS0013,Cryptography,696,,Weak cipher mode,unspecified,https://security-code-scan.github.io/#SCS0013,The ciphertext produced is susceptible to alteration by an adversary. This mean that the cipher provides no way to detect that the data has been tampered with. The use of AES in CBC mode with a HMAC is recommended guaranteeing integrity and confidentiality.',
    'SCS0014,SQL Injection,89,,Possible SQL injection in passed argument,high,https://security-code-scan.github.io/#SCS0014,The dynamic value passed in the SQL query should be validated.',
    'SCS0015,Password Management,259,,Hardcoded password,high,https://security-code-scan.github.io/#SCS0015,The password configuration to this API appears to be hardcoded. It is suggest to externalized configuration such as password to avoid leakage of secret information.',
    'SCS0016,Other,352,Y,Controller method is vulnerable to CSRF,medium,https://security-code-scan.github.io/#SCS0016,The annotation [ValidateAntiForgeryToken] is missing. It can be ignored/suppressed if .NET Core AutoValidateAntiforgeryToken is set up globally.',
    'SCS0017,Request Validation,?,,Request validation disabled in base class,unspecified,https://security-code-scan.github.io/#SCS0017,Request validation is disabled. Request validation allows the filtering of some XSS patterns submitted to the application.',
    'SCS0018,Injection,22,Y,Path traversal: injection possible in passed argument,high,https://security-code-scan.github.io/#SCS0018,Event validation is disabled. The integrity of client-side control will not be validated on postback.',
    'SCS0019,Other,?,,OutputCache annotation is disabling authorization checks,unspecified,https://security-code-scan.github.io/#SCS0019,Having the annotation [OutputCache] will disable the annotation [Authorize] for the requests following the first one.',
    'SCS0020,SQL Injection,89,,OleDb API: SQL injection possible in passed argument,high,https://security-code-scan.github.io/#SCS0020,The dynamic value passed in the SQL query should be validated.',
    'SCS0021,Request Validation,?,,Request validation has been disabled,unspecified,https://security-code-scan.github.io/#SCS0021,Request validation providing additional protection against Cross-Site Scripting (XSS) has been disabled.',
    'SCS0022,Other,?,,Event validation is disabled,unspecified,https://security-code-scan.github.io/#SCS0022,Event validation is disabled. The integrity of client-side control will not be validated on postback.',
    'SCS0023,View State,?,,View state is not encrypted,unspecified,https://security-code-scan.github.io/#SCS0023,View state is not encrypted. Controls may leak sensitive data that could be read client-side.',
    'SCS0024,View State,?,,View state mac is disabled,unspecified,https://security-code-scan.github.io/#SCS0024,View state mac is disabled. The view state could be altered by an attacker. (This feature cannot be disabled in the recent version of ASP.net)',
    'SCS0025,SQL Injection,89,,Odbc API: SQL injection possible in passed argument,high,https://security-code-scan.github.io/#SCS0025,The dynamic value passed in the SQL query should be validated.',
    'SCS0026,SQL Injection,89,,MsSQL Data Provider: SQL injection possible in passed argument,high,https://security-code-scan.github.io/#SCS0026,The dynamic value passed in the SQL query should be validated.',
    'SCS0027,Other,?,,Open redirect: possibly unvalidated input in passed argument,unspecified,https://security-code-scan.github.io/#SCS0027,The dynamic value passed to the redirect should be validated',
    'SCS0028,Other,?,,Possibly unsafe deserialization,unspecified,https://security-code-scan.github.io/#SCS0028,Deserialization from untrusted source is unsafe.',
    'SCS0029,Injection,79,,Potential XSS vulnerability,high,https://security-code-scan.github.io/#SCS0029,The endpoint returns a variable from the client input that has not been encoded.',
    'SCS0030,Request Validation,?,,Request validation is not enabled for all HTTP requests,unspecified,https://security-code-scan.github.io/#SCS0030,The RequestValidationMode property specifies which ASP.NET approach to validation will be used.',
    'SCS0031,Injection,90,,Possible LDAP injection in passed argument,unspecified,https://security-code-scan.github.io/#SCS0031,The dynamic value passed in the LDAP query should be validated.',
    'SCS0032,Password Management,?,,The RequiredLength property of PasswordValidator should be set,unspecified,https://security-code-scan.github.io/#SCS0032,The minimal length of a passwords is too short.',
    'SCS0033,Password Management,?,,Too few properties set in PasswordValidator declaration,unspecified,https://security-code-scan.github.io/#SCS0033,Password requirements are weak. PasswordValidator should have more properties set.',
    'SCS0034,Password Management,?,,Property must be set,unspecified,https://security-code-scan.github.io/#SCS0034,This property must be set to increase password requirements strength.',
    'SCS0035,SQL Injection,89,,Possible SQL injection in passed argument,high,https://security-code-scan.github.io/#SCS0035,The dynamic value passed in the SQL query should be validated.',
    'SCS0036,SQL Injection,89,,Possible SQL injection in passed argument,high,https://security-code-scan.github.io/#SCS0036,The dynamic value passed in the SQL query should be validated.' 

    $toolRuleLookup = @{}
    convertfrom-csv $rules -Header $header | foreach-object { $toolRuleLookup[$_.code] = $_ }

    $toolRuleLookup
}

function Write-Report([string] $buildOutputPath, [string] $resultsOutputPath, $ruleLookup) {

	$timeNow = [datetime]::Now
	$toolName = "Security Code Scan"

	$header = @"
<?xml version="1.0" encoding="ISO-8859-1"?>
  <report date="$timeNow" tool="$toolName" generator="$toolName">
    <findings>
"@
	$header | Out-File $resultsOutputPath

	Write-Findings $buildOutputPath $resultsOutputPath $ruleLookup

	$footer = @'
    </findings>
  </report>
'@
	$footer | Out-File $resultsOutputPath -Append
}


function Write-Findings([string] $buildOutputPath, [string] $resultsOutputPath, $ruleLookup) {

	$toolName = 'Security Code Scan'

	Get-Content $buildOutputPath | Select-String 'warning\sSCS\d{4}:' | Sort-Object -Unique | ForEach-Object {

		$result = $_.tostring()
		write-verbose "Found result $result"

		if (-not ($result -match '^(?<file>.+)\((?<line>\d+),(?<column>\d+)\):\swarning\s(?<code>[^:]+):\s(?<description>.+)\s\[(?<projectPath>.+)\]$')) {
			write-warning "Unable to parse finding: $result"
			return
		}

		$code = $matches['code']
		$file = $matches['file']
		$line= $matches['line']
		$description = $matches['description']
		$projectPath = $matches['projectPath']

		$rule = $ruleLookup[$code]
		if ($null -eq $rule) {
			write-warning "Unable to find tool code $code for result: $result"
			return
		}

		$filePath = Join-Path (Split-Path $projectPath) $file
		
		$finding = @"
      <finding severity="$($rule.severity)">
        <cwe id="$($rule.cweid)"/>
        <tool code="$code" category="$($rule.category)" name="$toolName"/>
        <location path="$filePath" type="file">
          <line start="$line"/>
        </location>
        <description format="markdown">$($rule.name) - $description \([details]($($rule.url))\).</description>
      </finding>
"@
		if ($rule.cweid -eq '?') {
			$finding = $finding.Replace('        <cwe id="?"/>', '')
		}

		$finding | Out-File $resultsOutputPath -Append
	}
}
