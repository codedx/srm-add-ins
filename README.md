# Code Dx Add-In Tools

New Code Dx deployments will include all available Code Dx Add-Ins. You can update existing Code Dx instances by registering Add-Ins using the configuration details in the sections below.

For details on creating your own Code Dx Add-Ins, refer to the "Walkthrough: Add Tool" section of the [Tool Orchestration](https://community.synopsys.com/s/document-item?bundleId=codedx&topicId=user_guide%2FAnalysis%2Ftool-orchestration.html&_LANG=enus) documentation.

## Black Duck

The TOML for this Add-In is located [here](./build/blackduck-dotnet/blackduck-example.toml).

>Note: Refer to the [Dockerfile](./build/blackduck/Dockerfile) for the list of installed detectors, and derive Docker images as necessary to support non-rapid scans.

![Black Duck](./docs/BlackDuck.PNG)

## Black Duck Rapid Scan

The TOML for this Add-In is located [here](./build/blackduck/blackduck-rapid-scan-example.toml).

>Note: Refer to the [Dockerfile](./build/blackduck/Dockerfile) for the list of installed detectors.

![Black Duck Rapid Scan](./docs/BlackDuckRapidScan.PNG)

# Burp Suite

The TOML for this Add-In is located [here](./build/burpsuite/burpsuite-example.toml).

![Burp Suite](./docs/Burp%20Suite.PNG)

# Checkmarx

The TOML for this Add-In is located [here](./build/checkmarx/checkmarx-example.toml).

![Checkmarx](./docs/Checkmarx.PNG)

# Coverity

The TOML for this Add-In is located [here](./build/coverity-dotnet/Coverity-dotnet-example.toml).

>Note: To use this add-in, you must derive a new Docker image with a licensed copy of Coverity. Refer to [specialize.ps1](https://github.com/codedx/codedx-add-ins/blob/main/build/coverity/specialize.ps1) for details on how to build your own Docker image. The resulting Docker image will support buildless scans via cov-capture, and you can derive additional Docker images to run builds with cov-build.

# ErrCheck

The TOML for this Add-In is located [here](./build/golangci-lint/golangci-lint-errorcheck-example.toml).

![ErrCheck](./docs/ErrCheck.PNG)

# Go Vet

The TOML for this Add-In is located [here](./build/govet/govet-example.toml).

![Go Vet](./docs/Go%20Vet.PNG)

# GoLint

The TOML for this Add-In is located [here](./build/golangci-lint/golangci-lint-golint-example.toml).

![GoLint](./docs/GoLint.PNG)

# GoSec

The TOML for this Add-In is located [here](./build/gosec/gosec-example.toml).

![GoSec](./docs/GoSec.PNG)

# Ineffassign

The TOML for this Add-In is located [here](./build/golangci-lint/golangci-lint-ineffassign-example.toml).

![Ineffassign](./docs/Ineffassign.PNG)

# Security Code Scan

The TOML for this Add-In is located [here](./build/securitycodescan/SecurityCodeScan-example.toml).

![Security Code Scan](./docs/Security%20Code%20Scan.PNG)

# Staticcheck

The TOML for this Add-In is located [here](./build/staticcheck/staticcheck-example.toml).

![Staticcheck](./docs/Staticcheck.PNG)

# ZAP

The TOML for this Add-In is located [here](./build/zap/zap-example.toml).

![ZAP](./docs/ZAP.PNG)

# ZAP API

The TOML for this Add-In is located [here](./build/zap/zap-api-scan-example.toml).

![ZAP](./docs/ZAPAPI.PNG)
