# Here You Go super-admin panel

Private static monitoring website. The existing Firebase project remains the identity and data source; the existing Render free service enforces admin authorization. Sites owner-private access remains enabled as an additional hosting boundary.

## First access

Open the published site while signed into its owning ChatGPT account. Sign in with the approved admin email and password. The project owner can provision a specific Firebase account UID with password-only access; that account does not need to verify its email. No password is embedded in source, deployment files or the client bundle. Use **About this panel → Change password** to replace your initial password.

Authorization lives in server-only `adminAccess/{uid}` documents. Each record has `role: "superadmin"`, `email`, and `enabled: true`. The project owner may set `requireEmailVerification: false` for an explicitly approved UID. The default for other roles still requires verification. Every request rechecks the UID, role, enabled flag and email. The UI does not create accounts or self-grant roles. Legacy invitation activation still requires verified email; an unverified invitation alone cannot activate access. Revoking the role cannot be undone by an invitation. Client Firestore rules deny all reads/writes to admin roles, invitations and activity logs.

## Monitoring

- Orders, statuses, items, totals, customers, vendors, assignments and last tracking point.
- Vendor profiles, owner contact details, inventory and pickup locations.
- Delivery partner contacts, availability, GPS age/accuracy and active delivery.
- Saved customer profiles; authentication-only accounts without profiles are not listed as customers.
- Transactional activity records for orders, assignments, status changes, courier registration/profile updates through the service, and online/offline changes. No event is added for every GPS heartbeat. Earlier history and direct profile/catalog edits are not retroactively logged.
- Exact order lookup, server-filtered order status, bounded cursor pagination, search within loaded records and CSV export of those records. Handover codes are never returned.
- Refresh every minute while the tab is visible and active; pauses after five idle minutes, when searching/browsing older pages and while details are open. Free Render may take about a minute to wake up.

Order value is completed cash-on-delivery order value including fees, not settled revenue or payouts. Operational data is read-only; administrators can also change their own password.

## Development and release

Buildless: `dist/` is the complete static application. `node scripts/preview.cjs` serves the real login locally. `--emulator` swaps only the local preview configuration for `demo-route-rescue`, Auth 9199 and the standalone API 10000. This option is never part of the hosted deployment. Firebase SDK 12.19.0 is pinned via Google's official CDN.

Backend: `../functions/admin.js`, used by the authenticated callable at `/fulfillment`. Deploy the updated server and the indexes in `../firestore.indexes.json` before publishing the panel. Backend and security tests: root `npm run test:standalone` with Java 21 on PATH. Static syntax: `node --check dist/app.js`.

This folder is tracked directly in the main `Greeshma-05/hereyou-go` GitHub repository, alongside the three apps and backend. From the repository root, run `node admin_panel/scripts/preview.cjs` to preview it. It is a regular folder, not a Git submodule.

Publish using the Sites skill, preserving `.openai/hosting.json` identity and its owner-private audience. Use a separate temporary checkout for Sites source synchronization; copy this folder's source into that checkout before packaging and publication. The existing Sites source repository retains its deployment history. Pushing the main GitHub repository does not publish the website. The separate private `here-you-go-orders` repository still supplies the Render server deployment.
