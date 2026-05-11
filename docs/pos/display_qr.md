BASE64=$(base64 < test_table1.png | tr -d '\n') 

cat > payload.json <<EOF
{
  "shopCode": "0001",
  "shopCodeCst": "",
  "tagID": "810000E3AFF6",
  "base64Data": "$BASE64",
  "batchID": "test-001",
  "isDither": true
}
EOF

curl -X POST http://10.10.10.1:5000/api/esl/tag/Image \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @payload.json