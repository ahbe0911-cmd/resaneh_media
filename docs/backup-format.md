# Resaneh backup formats

Version 1.1.0 retains format-1 ZIP compatibility (manifest, SHA-256, application ID and database migration checks).

Optional encrypted backups use the .rmb envelope, version 2. This is not a password-protected standard ZIP. It wraps a complete format-1 ZIP.

Header (40 bytes, big-endian):
- 8-byte magic: 52 53 4e 48 42 4b 02 00
- 16-byte random PBKDF2 salt
- 8-byte random nonce prefix
- 8-byte unsigned plaintext size

PBKDF2-HMAC-SHA256 with 600,000 iterations derives the 256-bit AES key. Each record holds up to 1 MiB ciphertext and a 16-byte GCM tag. Nonce: 8-byte prefix + 4-byte record index. AAD: entire header + record index. Exact expected file size and all record tags must validate before the inner ZIP is unpacked. The inner manifest preserves flavor separation. No passwords are stored. Plaintext staging remains in app-private cache and is removed at completion or next cold start, not guaranteed secure erasure.

Progress reflects measured files processed or bytes encrypted/decrypted within weighted stages; snapshot copying, Android SAF transfer, database validation and atomic commit use indeterminate indicators.

Release gates: static analysis, unit/widget tests, both APK builds, package/signing validation and SHA-256 artifacts. Device testing (large archive, power interruption, real biometrics, and actual update signing continuity) remains necessary before production deployment.
