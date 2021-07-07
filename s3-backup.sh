#!/bin/bash

ENCRYPTION_KEY=/secret/encryption.key

usage () {
    cat <<EOF
This tool requires an encryption key in $ENCRYPTION_KEY
and the following environment variables
- S3_ACCESS_KEY
- S3_BUCKET
- S3_DEST_DIR
- S3_SECRET_KEY
- S3_ENDPOINT (accessed via HTTPS)
EOF
    exit 1
}

# Exit on error or if unset variables are expanded
set -eu

# Configure "dest" alias
export MC_HOST_dest="https://$S3_ACCESS_KEY:$S3_SECRET_KEY@$S3_ENDPOINT"
dest="dest/$S3_BUCKET/$S3_DEST_DIR/"

# Generate a key ID (to identify the key used when they are rotated)
keyid=$(sha256sum $ENCRYPTION_KEY | cut -c 1-5)

# S3_* env vars are required, the url must be properly formatted, and
# there must be an encryption key
if [[ ! -f $ENCRYPTION_KEY ]]; then
    usage
fi

# Show commands
set -x

backup=/tmp/backup-$(date +%Y%m%d-%H%M).tar.xz
outfile="$backup.enc.$keyid"
tar -cJvf $backup --directory /input .

# Encrypt the tarball contents using a key mounted to
# $ENCRYPTION_KEY
gpg --batch \
    --quiet \
    --passphrase-file $ENCRYPTION_KEY \
    --output "$outfile" \
    --symmetric \
    --cipher-algo AES256 \
    $backup

# Decrypting:
#gpg --batch \
#    --passphrase-file $ENCRYPTION_KEY \
#    --decrypt \
#    "$backup.enc"

# Copy 
mc cp \
   --quiet \
   --preserve \
   "$outfile" \
   "$dest"
