# Live Activities Test Instructions

## Setup Complete ✅
- Widget Extension added: PixieWidgetExtension
- Live Activity widget configured with enhanced completion states
- Shared attributes accessible to both targets
- Background task handling integrated
- Dynamic Island expansion on completion (iPhone 14 Pro+)

## To Test:
1. Run the app on a physical device or simulator with iOS 16.2+
2. Start an image generation or edit
3. Immediately press Home button to background the app
4. Check for:
   - Live Activity on Lock Screen
   - Dynamic Island content (on supported devices)
   - **NEW**: Dynamic Island expands on completion instead of notification (iPhone 14 Pro+)
   - Regular notification on older devices

## Dynamic Island Behavior:
- **During generation**: Shows progress indicator
- **On completion**: Expands with "Ready to view!" message
- **On failure**: Expands with error message
- **Auto-dismisses**: After 10 seconds

## Debug:
- Live Activities are logged with IDs in the console
- Background task notifications show completion status
- Check Settings > Pixie to ensure Live Activities are enabled
- Console shows "🎯 Expanded Live Activity for completion" when expanding

## Known Configuration:
- Bundle ID: com.guitaripod.Pixie
- Widget Extension ID: com.guitaripod.Pixie.WidgetExtension
- App Group: group.com.guitaripod.Pixie
- Dynamic Island minimum height: 852px (iPhone 14 Pro+)