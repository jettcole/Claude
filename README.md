# Tallyroll

A payment recorder for a phone. Tap what you sold, pick the size, take the money,
hit **Complete purchase** — and it logs what went out, in what size, and for how much.

Everything runs on the phone itself. No account, no server, no signal required.
Sales export as a CSV file you can open in Numbers, Excel or Google Sheets.

## Put it on your iPhone

Tallyroll is a web app, so there is no App Store review, no Mac, no Xcode and no
$99/year developer account. It needs to be served over HTTPS once, and GitHub
Pages does that for free straight out of this repository.

1. On GitHub, open this repo → **Settings** → **Pages**.
2. Under *Build and deployment*, set **Source** to `Deploy from a branch`,
   pick the branch holding these files and the `/ (root)` folder, then **Save**.
3. Wait about a minute and GitHub shows a URL like
   `https://<your-username>.github.io/<repo>/`.
4. Open that URL **in Safari on your iPhone** (Safari specifically — Chrome on
   iOS cannot install home-screen apps).
5. Tap the Share button, scroll down, tap **Add to Home Screen**, then **Add**.

You now have a Tallyroll icon on your home screen. It opens full screen with no
browser chrome, and it keeps working in airplane mode — the service worker caches
the whole app on first load.

> Open it once while you still have signal so the cache fills, then it is yours
> offline for good.

**Add it to the home screen before you start recording sales.** iOS gives a
home-screen web app its own storage, separate from Safari's, so anything entered in
the Safari tab beforehand will not be there once it is installed. Install first,
then enter your items.

## Using it

**Items** — Everything you sell lives here. An item can have one price, or as many
named sizes and prices as it needs:

| Item | Sizes |
|---|---|
| Latte | Small $3.50 · Medium $4.25 · Large $5.00 |
| Croissant | one price, $3.75 |
| Hoodie | M $38.00 · L $42.50 |

An item with a single unnamed size drops straight into the sale on one tap. Give it
two or more and Tallyroll asks which size first.

**Discounts** — Set up named discounts, either a percentage or a flat amount off.
At checkout they become buttons you tap to apply. Several can stack, each one
working on what is left after the one before it.

**Photos instead of names** — Any item can carry a photo, taken with the phone's
camera straight from the item editor. Where there is a photo, the Sell screen shows
it in place of the name, which is quicker to hit accurately with a queue waiting.
The name still rides along on receipts, in the log and in every export, so nothing
is lost. Photos are cropped square and scaled down before they are stored, so a
whole menu of them costs a fraction of the phone's storage.

**Sell** — Tap items to build the sale. The running total sits at the bottom of the
screen. Tap **Checkout** to change quantities, apply discounts, choose how it was
paid (cash, card or other) and add a note. **Complete purchase** records it.

**Cash and change** — With Cash selected, checkout shows a keypad field for what the
customer handed over, alongside one-tap buttons for the exact amount and the notes
people usually pay with. The change to give back is worked out as you type and
repeated in the pinned footer, so it never needs a scroll:

```
Received                        20.00
Change due                      $9.63
```

Hand over less than the total and it flips to **Still owed**, in red, with the
shortfall. Both the cash received and the change given are recorded on the sale.

**Why this price** — Checkout shows every discount that has been applied and the
arithmetic behind it, so an unusual price can be justified on the spot:

```
Subtotal                       $13.75
Regular                        -$1.38
  10% of $13.75
Staff                          -$2.00
  flat $2.00 off
Taken off in total             -$3.38
Total                          $10.37
```

The same breakdown appears on the saved receipt afterwards, and lands in the CSV.

**Log** — Today's takings, the count of sales, and the all-time total, then every
sale grouped by day. Tap one to see its receipt.

Recorded a sale by mistake? Open it and **Void** it. A voided sale stays visible in
the log and in exports, but stops counting toward any total — which is what you
want when the takings have to reconcile. Delete removes it outright.

**Settings** — Your business name (it prints on receipts), the currency symbol, and
an optional tax rate applied after discounts.

## Getting the sales out

**Log → Export** produces a CSV with one row per item sold:

```
sale_id,date,time,item,size,qty,unit_price,line_total,sale_subtotal,
sale_discount,sale_tax,sale_total,payment_method,cash_received,
change_given,discounts_applied,voided,note
```

`discounts_applied` carries the same reasoning shown at checkout, e.g.
`Regular (10% of $13.75); Staff (flat $2.00 off)`.

On an iPhone this opens the normal share sheet, so you can drop the file into
Files, mail it to yourself, or AirDrop it to a laptop. Amounts are written as plain
numbers with no currency symbol, so spreadsheets add them up without complaint.

**Settings → Export backup** writes a single file holding your items, discounts,
settings and every sale. **Restore from backup** reads it back — that is how you
move to a new phone.

## Is it really offline?

Yes, after one online load. On that first visit a service worker caches the app —
markup, styles, logic, icons and the web fonts — into the browser's cache storage.
After that it never needs the network:

- The app opens and runs cold with the phone in airplane mode.
- Sales, change calculations, item photos and CSV exports all happen on the device.
- Nothing is sent anywhere. There is no server, no account and no analytics; while
  you are using it the app makes no network requests at all.

The one thing that needs signal is the very first load, which is why it is worth
opening it at home before a market rather than at the stall.

If the web fonts fail to load — a locked-down network, a first load that half
finished — the app falls back to the system typefaces and works exactly the same.

## Where your data lives

In this browser's local storage on this phone, and nowhere else. Nothing is
uploaded anywhere, which is what keeps it working offline — and also means:

- Deleting the app from your home screen, or clearing Safari's website data, takes
  the sales and item photos with it.
- Private browsing blocks storage entirely; Tallyroll warns you in Settings if that
  happens.

**Export a backup regularly.** It is the only copy that survives losing the phone.

## Money and rounding

Every amount is held as a whole number of cents and percentages as basis points, so
totals are never the result of adding floating-point numbers together. Percentage
discounts round half up on the amount taken off: 10% of $13.75 is $1.375, recorded
as $1.38 off, leaving $12.37.

## What's in here

```
index.html            the entire app — markup, styles and logic in one file
sw.js                 service worker; caches the app shell for offline use
manifest.webmanifest  name, colours and icons for the home-screen install
icons/                app icons
tools/make_icons.py   regenerates the icons (pure Python, no dependencies)
```

## Working on it

Any static file server will do:

```sh
python3 -m http.server 8000
```

Then open `http://localhost:8000`. Service workers need HTTPS or `localhost`, so
offline caching is inactive over a plain LAN IP — everything else still works.

After changing `index.html`, bump `CACHE` in `sw.js` so installed phones pick up the
new version rather than serving the cached one.
