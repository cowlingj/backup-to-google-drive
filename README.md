# backup-to-google-drive
A set of bash programs to create a backup and upload it to google drive

## Tests

### Backup
- None yet

### Get Auth Token
- Creates a credentials file suitable for **Send File**

### Send File
- The tests upload a gziped file to google drive

## Credentials

1. Get a set of OAuth credentials from Google's API console
2. Create a `creds.json` file with keys `client_id`, `client_secret`, `scope`
3. Fill the creds.json file

> Tests expect a creds.json file in the test directory
