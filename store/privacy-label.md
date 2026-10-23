# PixiePocket App Privacy label

Answers for App Store Connect, App Privacy section. Apple does not expose this section through the API, so the founder enters it by hand. It matches `iOS/Pixie/Pixie/Resources/PrivacyInfo.xcprivacy` (the widget extension collects nothing and ships no manifest) and the policy at https://midgarcorp.cc/legal/pixiepocket/privacy (source: `web/midgarcorp/src/content/legal/pixiepocket/privacy.html`, last updated 23 October 2026). The Privacy Policy URL on the app info (`store/metadata/ios/app-info/*.json`) moves from `https://mako.midgarcorp.cc/privacy/pixiepocket` to that address with this release; `midgar listing` pushes it and, under the `metadata_edit` policy, only with the founder at a terminal. The old address redirects with a 301, so the live record keeps working until then.

This replaces whatever label the app carried before, which predates the Midgar ID and, if it said that images stay on the device, understated what mako keeps.

## Top-level answers

- Do you or your third-party partners collect data from this app: Yes.
- Data used to track you: none. No data type is used for tracking. The app asks for no tracking permission and `NSPrivacyTracking` is false with no tracking domains.
- Privacy policy URL: https://midgarcorp.cc/legal/pixiepocket/privacy

## Data types collected

| Data type (Apple) | Linked to the user | Used to track | Purpose | What it is in PixiePocket |
| --- | --- | --- | --- | --- |
| Contact Info, Name | Yes | No | App Functionality | Only when the person signs in with Apple, Google or GitHub: the name the provider shares, stored on the mako account. |
| Contact Info, Email Address | Yes | No | App Functionality | Only when the person signs in with Apple, Google or GitHub: the address the provider shares (Apple may share a private relay address), stored on the mako account. |
| Identifiers, User ID | Yes | No | App Functionality | The anonymous mako account id and API key that hold the credit balance and gallery, the random Midgar ID, and the RevenueCat app user id, which is the mako account id. |
| Purchases, Purchase History | Yes | No | App Functionality | The App Store transactions of credit packs. RevenueCat verifies them and mako records them against the account. |
| Photos or Videos | Yes | No | App Functionality | The photos a person attaches for editing, sent to mako and on to Google Gemini or OpenAI (mako keeps no copy), and every image the app generates or edits, which mako stores in the person's private gallery until they delete it or the account. |
| User Content, Other User Content | Yes | No | App Functionality | The text of every prompt, which mako keeps in its usage record of the request. |
| Usage Data, Product Interaction | No | No | Analytics | The anonymous More Apps events (opened, shown, tapped) sent by MidgarKit with no identifier. |

Everything else is "Data Not Collected".

## Data types answered "not collected", and why

- Contacts, Browsing History, Search History, Sensitive Info, Financial Info, Health & Fitness, Location: none. The photo picker hands over only the photos a person chooses; the recent-photos strip is read on the device and only a photo the person taps leaves it.
- Identifiers, Device ID: the app reads no advertising identifier and no vendor identifier and sends no attribution token (AICredits' ad attribution is never started). This release ships without the App Attest entitlement, so MidgarKit creates no key id yet; once it is enabled, the key id is per app and per device and is used only to prove the app is genuine when the Midgar ID is created or joined. If App Review reads it as a Device ID, the fallback is Device ID, App Functionality, linked.
- Diagnostics: the session log (`Library/Logs/pixie.log`) stays on the device. MetricKit is not collected.
- Other Data: none.

## Check before the label is entered

- The tenant's `apps.store_prompts` and `apps.store_images` are 1 by default (migration `020_tenant_privacy_flags.sql` switches them off only for `dreameater`), so mako keeps prompt text and stores generated images for `pixie`. This pass did not read the production `pixie` row; the policy and this label assume the defaults. If a flag was changed in production, the matching row above can stay (the data still leaves the device).
- mako stamps every stored image with an `expires_at` seven days out, but the worker has no job that deletes expired rows or R2 objects. The policy therefore says images stay "until you delete them or your account", which is what the code does. If expiry is enforced some other way (an R2 lifecycle rule), the policy can be made shorter.
- Account deletion in the app erases the mako account, its images, usage records and credit rows, but not the shared Midgar ID, which the other Midgar apps use; the policy says so and gives the support address.

## Third-party SDK notes

- RevenueCat (full purchase mode, RevenueCat finishes every transaction): processes purchase data on our behalf; its manifest declares Purchase History and User ID. The Midgar ID is not sent to RevenueCat in this release, so the two identifiers are not joined by the app.
- Google Sign-In: used only when the person chooses Google; Google's SDK ships its own manifest. The server auth code and ID token go to mako, which stores the name and email address.
- MidgarKit: `MidgarPortal` ships a manifest that declares Product Interaction for Analytics, not linked, matching the row above.
- Google (Gemini) and OpenAI are reached only through mako, which is the service that sends them the prompt or photo.
- Cloudflare: hosts the gateway, the services behind it and the R2 storage of generated images, and may keep standard request logs (IP address) for a limited time; IP address is not a data type in the label.

## Required-reason APIs (in the manifest, not in the label)

- UserDefaults `CA92.1` (own settings, drafts and review state).
- File timestamp `C617.1` (the Live Activity thumbnails in the app group container are swept by modification date).
