# Security Policy

## Supported Versions

Security updates are provided for the latest version on the `main` branch.
Older commits and independently modified copies are not supported.

## Disclaimer

This software is provided **as is**, without warranty of any kind. Use it at
your own risk. The complete warranty disclaimer and limitation of liability are
set out in the `LICENSE` file.

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues,
discussions, or pull requests.

Use GitHub's private vulnerability reporting feature instead:

1. Open the repository's **Security** tab.
2. Select **Advisories**.
3. Select **Report a vulnerability**.

Include the following information where possible:

- A description of the vulnerability and its potential impact.
- The affected version or commit.
- Steps required to reproduce the issue.
- Any proof-of-concept code, logs, or screenshots needed to confirm it.
- Suggested mitigations or fixes, if available.

Remove API keys, tenant information, hostnames, license identifiers, and other
sensitive operational data from submitted logs and screenshots.

The maintainers will acknowledge the report, investigate it, and coordinate a
fix and disclosure timeline with the reporter. Please allow a reasonable amount
of time for remediation before making vulnerability details public.

## Security Considerations for Deployment

- Never commit `sm-it_veeamVSPCLicenses_Includes/config.ps1` or any other file
  containing a VSPC API key.
- Restrict access to the configuration file and the PRTG execution account.
- Grant the VSPC API key only the permissions required by this integration.
- Use HTTPS with a valid, trusted certificate for the VSPC API endpoint.
- Rotate the API key immediately if it may have been exposed.
- Review debug output before sharing it because it can contain tenant names,
  hostnames, license identifiers, and other operational information.
