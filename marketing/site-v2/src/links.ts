/**
 * Outbound links, in one place.
 *
 * Every "Join the beta" on the page points here. They were briefly anchor links
 * and one pointed at bare testflight.apple.com — Apple's homepage rather than
 * the beta — so a single constant is what stops that recurring.
 *
 * Deliberately NOT an email-capture form. A public TestFlight link converts in
 * one tap; a form adds a step, and it would mean holding a list of addresses
 * this product has no other reason to store.
 *
 * Same tab, no target="_blank": on iPhone this hands off to the TestFlight app,
 * which is the whole point, and a new tab just leaves an orphan behind.
 */
export const TESTFLIGHT_URL = 'https://testflight.apple.com/join/tGubSF3Z'

/** Apple's TestFlight app — must be installed before the join link resolves. */
export const TESTFLIGHT_APP_URL = 'https://apps.apple.com/app/testflight/id899247664'

/** Scanned by desktop visitors to open the beta on their phone. Generated from
 *  TESTFLIGHT_URL — regenerate if that changes:
 *  npx qrcode -t svg -o public/testflight-qr.svg -e M -w 4 "<url>" */
export const TESTFLIGHT_QR = '/testflight-qr.svg'
