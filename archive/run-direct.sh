#!/bin/sh
cp /dast/zscaler-root-ca.crt /usr/local/share/ca-certificates/
update-ca-certificates
/app/bin scan --base-url https://sng.ast.checkmarx.net --environment-id 6df27a14-a6c0-4d07-81c5-1c8e304bd06a --url https://devsecops360.fusion.co.th --custom-headers 'HEADERS_PLACEHOLDER' --verbose
