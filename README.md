# CAS-ImageSupport

Reusable image picking, cropping, viewing, and sharing support for Creative App Solutions applications.

## Requirements

- Xcode 26 or newer
- iOS 26 or newer
- Mac Catalyst 26 or newer

## Installation

Add the package dependency using:

`https://github.com/KMessina1/CAS-ImageSupport.git`

Then import the library where required:

```swift
import CASImageSupport
```

## App-owned share access

`needsPurchasable: Bool = false` is a caller-provided restriction, not an entitlement check. Existing callers remain unrestricted by default.
When true, Share shows "Subscription Required" / "This choice requires a subscription." and does not open the activity sheet, including its Print action. Supply `subscriptionDestination: AnyView(...)` to provide the host app's Subscriptions destination. The package does not import or read purchase state.
