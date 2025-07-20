use clap::Subcommand;

#[derive(Subcommand)]
pub enum AuthProvider {
    #[command(about = "Authenticate with GitHub OAuth", long_about = "Authenticate using your GitHub account.

EXAMPLE:
  pixie auth github

This will:
  1. Open your browser to GitHub OAuth page
  2. Request permission to authenticate
  3. Save credentials locally for future use")]
    Github,
    
    #[command(about = "Authenticate with Google OAuth", long_about = "Authenticate using your Google account.

EXAMPLE:
  pixie auth google

This will:
  1. Show a device code to enter on Google's device page
  2. Open your browser for authentication
  3. Save credentials locally for future use")]
    Google,
    
    #[command(about = "Authenticate with Apple OAuth (coming soon)", long_about = "Authenticate using your Apple ID.

EXAMPLE:
  pixie auth apple

Note: Apple authentication is coming soon!")]
    Apple,
    
    #[command(about = "Check device authentication status", long_about = "Check the status of a device authentication flow.

EXAMPLE:
  pixie auth device-status <device-code>

PURPOSE:
Device authentication is used when a direct browser redirect isn't possible
(e.g., CLI tools, mobile apps, smart TVs). This command checks if a user
has completed the authentication process for a given device code.

WHEN TO USE:
- Debugging: Check if a user completed authentication after seeing a device code
- Support: Help users troubleshoot stuck authentication flows
- Testing: Verify device authentication is working correctly

EXPECTED STATUSES:
- pending: User hasn't completed authentication yet
- completed: Authentication successful, token was issued
- expired: Device code expired (typically after 15 minutes)
- invalid: Device code doesn't exist or was already used

NOTE: This is primarily for debugging and support purposes. Regular users
typically won't need this command as the auth flow handles polling automatically.")]
    DeviceStatus {
        #[arg(help = "Device code to check status for")]
        device_code: String,
    },
}