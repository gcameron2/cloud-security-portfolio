#!/usr/bin/env bash
# Prowler audit runner — production-style execution script
# Usage: ./run-prowler.sh [full|iam|s3]

set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
OUTPUT_DIR="reports"
AUDIT_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/ProwlerAuditRole"

mkdir -p "$OUTPUT_DIR"

SCAN_TYPE="${1:-full}"

echo "=== Prowler Security Audit ==="
echo "Account:   $ACCOUNT_ID"
echo "Timestamp: $TIMESTAMP"
echo "Scan type: $SCAN_TYPE"
echo "Output:    $OUTPUT_DIR"
echo ""

case "$SCAN_TYPE" in
  iam)
    echo "Running IAM-only scan..."
    prowler aws \
      --role "$AUDIT_ROLE" \
      --service iam \
      --output-formats json-ocsf html \
      --output-directory "$OUTPUT_DIR" \
      --output-filename "prowler-iam-${ACCOUNT_ID}-${TIMESTAMP}"
    ;;
  s3)
    echo "Running S3-only scan..."
    prowler aws \
      --role "$AUDIT_ROLE" \
      --service s3 \
      --output-formats json-ocsf html \
      --output-directory "$OUTPUT_DIR" \
      --output-filename "prowler-s3-${ACCOUNT_ID}-${TIMESTAMP}"
    ;;
  full)
    echo "Running full scan (IAM, S3, EC2, VPC, CloudTrail, KMS)..."
    prowler aws \
      --role "$AUDIT_ROLE" \
      --service iam s3 ec2 vpc cloudtrail kms \
      --output-formats json-ocsf html csv \
      --output-directory "$OUTPUT_DIR" \
      --output-filename "prowler-full-${ACCOUNT_ID}-${TIMESTAMP}"
    ;;
  *)
    echo "Unknown scan type: $SCAN_TYPE"
    echo "Usage: $0 [full|iam|s3]"
    exit 1
    ;;
esac

echo ""
echo "=== Scan complete ==="
echo "Reports saved to: $OUTPUT_DIR/"
echo ""
echo "Open the HTML report in your browser:"
echo "  $OUTPUT_DIR/prowler-${SCAN_TYPE}-${ACCOUNT_ID}-${TIMESTAMP}.html"
