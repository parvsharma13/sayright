#!/bin/bash
# Creates a self-signed code-signing certificate in the login keychain so that
# rebuilt copies of SayRight.app keep the same code signature. Without it macOS
# revokes the Accessibility permission on every rebuild.
# Run once:  make cert
set -euo pipefail
umask 077
NAME="${1:-SayRight Self Signed}"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
    echo "Certificate '$NAME' already exists."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Only protects this short-lived local export. Never store a signing password in source.
export SAYRIGHT_CERT_PASSWORD="$(openssl rand -hex 32)"

cat > "$TMP/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
1.2.840.113635.100.6.1.13 = critical,DER:05:00
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout env:SAYRIGHT_CERT_PASSWORD -legacy

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
echo "Importing into the login keychain (macOS may ask for your password)..."
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$SAYRIGHT_CERT_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
unset SAYRIGHT_CERT_PASSWORD
security set-key-partition-list -S apple-tool:,apple: -k "" "$KEYCHAIN" >/dev/null 2>&1 || \
    echo "note: could not set the partition list; codesign may prompt for your password once."
security add-trusted-cert -d -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" 2>/dev/null || \
    echo "note: certificate not marked as trusted; that is fine for local signing."

echo "Done. '$NAME' is ready - run 'make bundle'."
