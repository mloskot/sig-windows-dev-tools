#!/bin/bash
set -x
addressport="$1"
curl -v -f -k -m 10 \
    --header "Content-Type: application/soap+xml;charset=UTF-8" \
    --header "WSMANIDENTIFY: unauthenticated" \
    --data "<s:Envelope xmlns:s=http://www.w3.org/2003/05/soap-envelope xmlns:wsmid=http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd><s:Header/><s:Body><wsmid:Identify/></s:Body></s:Envelope>" \
    http://${addressport}/wsman


# Expected output indicating WinRM connectivity works is:
#
# <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Header/>
#   <s:Body><wsmid:IdentifyResponse xmlns:wsmid="http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd">
#     <wsmid:ProtocolVersion>http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd</wsmid:ProtocolVersion>
#     <wsmid:ProductVendor>Microsoft Corporation</wsmid:ProductVendor><wsmid:ProductVersion>OS: 0.0.0 SP: 0.0 Stack: 3.0</wsmid:ProductVersion>
#   </wsmid:IdentifyResponse></s:Body>
# </s:Envelope>
