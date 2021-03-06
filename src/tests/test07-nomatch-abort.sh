#!/bin/sh
#
# Test --sni-nomatch-abort

. hitch_test.sh

PORT2=$(expr $LISTENPORT + 701)

cat >hitch.cfg <<EOF
sni-nomatch-abort = on

pem-file = "${CERTSDIR}/site1.example.com"
pem-file = "${CERTSDIR}/site2.example.com"
pem-file = "${CERTSDIR}/default.example.com"

backend = "[hitch-tls.org]:80"

frontend = {
	host = "localhost"
	port = "$LISTENPORT"
}

frontend = {
	host = "localhost"
	port = "$PORT2"
	pem-file = "${CERTSDIR}/site3.example.com"
	sni-nomatch-abort = off
}
EOF

start_hitch --config=hitch.cfg

if openssl s_client -help 2>&1 | grep -q -e -noservername;
then
	NOSNI="-noservername"
else
	NOSNI=""
fi

# No SNI - should not be affected.
s_client -connect localhost:$LISTENPORT $NOSNI >no-sni.dump
subject_field_eq CN "default.example.com" no-sni.dump

# SNI request w/ valid servername
s_client -servername site1.example.com \
	-connect localhost:$LISTENPORT >valid-sni.dump
subject_field_eq CN "site1.example.com" valid-sni.dump

# SNI w/ unknown servername
! s_client -servername invalid.example.com \
	-connect localhost:$LISTENPORT >unknown-sni.dump
run_cmd grep 'unrecognized name' unknown-sni.dump

# SNI request w/ valid servername
s_client -servername site1.example.com \
	-connect localhost:$PORT2 >valid-sni-2.dump
subject_field_eq CN "site3.example.com" valid-sni-2.dump

# SNI w/ unknown servername
s_client -servername invalid.example.com \
	-connect localhost:$PORT2 >unknown-sni-2.dump
subject_field_eq CN "site3.example.com" unknown-sni-2.dump

# Ancient curl versions may not support --resolve
# This would skip this test, keep it last
curl_hitch \
	--resolve site1.example.com:$LISTENPORT:127.0.0.1 \
	-- https://site1.example.com:$LISTENPORT/
