# InvoPrint PRD And Implementation Plan

## 1. Product Summary
**InvoPrint** is a Flutter desktop invoice application for small Indian businesses. It will create GST and non-GST invoices, quotations, PDFs, customer records, product/service shortcuts, payment tracking, and loyalty points. The app is cloud-first using Firebase, but each customer’s business data stays inside their own Firebase project.

The business model is a one-time ₹6000 desktop app license with setup support. The customer owns their Firebase project and pays any Firebase/Google Cloud charges directly. Your Firebase is used only as the control layer for login, license, updates, device limits, and customer Firebase config.

## 2. Target Users
Primary users:
- Small businesses
- Freelancers
- Service providers
- Retail/service shops
- GST and non-GST businesses
- Users who need simple invoice + quotation + print/PDF workflows

Main success goal:
- A user should be able to create a customer, prepare an invoice or quotation, generate a PDF, and print/share it quickly without needing accounting knowledge.

## 3. Product Positioning
Product name:
- **InvoPrint**

Suggested tagline:
- **GST invoices, quotations, and loyalty billing from your desktop.**

Core promise:
- Simple desktop billing with customer-owned cloud data.

## 4. Business Model And License Rules
Pricing:
- ₹6000 one-time desktop app license.

Recommended included limits:
- 1 business
- 1 Firebase project
- 1 or 2 desktop devices
- 30 days setup support
- 6 months minor updates
- Firebase/Google usage charges paid by customer

Paid extras:
- Extra device
- Extra business/GSTIN
- Long-term support
- Custom invoice templates
- Custom reports
- Data migration
- Advanced features

## 5. Cloud Architecture
Use two Firebase projects.

Your Firebase, called **Control Firebase**, stores:
- user login
- license status
- customer profile
- customer Firebase config
- device activation records
- latest app version
- download/update link
- support status
- admin-managed setup metadata

Customer Firebase stores:
- invoices
- quotations
- customers
- products/services
- company profile
- settings
- loyalty ledger
- small company logo/payment QR data as Firestore base64 fields

Customer Firebase does not use Firebase Storage in v1. Invoice and quotation PDFs are generated locally from saved Firestore data and saved on the user's desktop only when the user chooses.

Important rule:
- No invoice/business data should be stored in your Control Firebase.

## 6. Authentication Flow
The app shows one login screen, but internally uses two Firebase Auth sessions.

Login flow:
1. User enters email and password.
2. App logs into your Control Firebase Auth.
3. App verifies license, device limit, support status, and app version.
4. App fetches the customer Firebase config.
5. App initializes the customer Firebase project dynamically.
6. App logs into customer Firebase Auth using the same email/password.
7. App opens the dashboard only if both sessions succeed.

Failure handling:
- If control login fails: show invalid login/license message.
- If license inactive: block access and show support contact.
- If customer config missing: show setup incomplete message.
- If customer Firebase login fails: show password/account sync support message.

## 7. Password Management
V1 rule:
- Password changes must happen only inside InvoPrint or through support.

If in-app password change is included:
1. Ask current password, new password, confirm password.
2. Re-authenticate both Firebase users.
3. Update customer Firebase password first.
4. Update Control Firebase password second.
5. Sign out from both sessions.
6. Ask user to log in again.

Do not manage or request the customer’s Google account password. Only manage Firebase Auth app-user passwords.

## 8. Main Desktop Modules
The app should have these main sections:
- Dashboard
- Invoices
- Quotations
- Customers
- Products/Services
- Loyalty
- Reports
- Settings
- Updates/Support

Recommended first screen after login:
- Dashboard with recent invoices, unpaid total, paid total, this month sales, quotation count, and quick-create buttons.

## 9. Company Profile Features
Company profile fields:
- business name
- owner/contact person
- address
- phone
- email
- GSTIN optional
- state
- logo
- bank name
- account number
- IFSC
- UPI ID
- payment QR image
- default terms and conditions

GST should be optional at company level, but invoice-level GST mode must still be selectable.

## 10. Customer Features
Customer fields:
- customer name
- phone
- email
- billing address
- shipping address optional
- GSTIN optional
- state
- default discount optional
- loyalty enabled customer flag optional
- notes

Customer actions:
- add/edit/delete/archive
- search
- view invoices
- view quotations
- view loyalty points
- view outstanding amount

## 11. Product/Service Features
Products/services are optional helpers, not mandatory for invoices.

Product/service fields:
- name
- description
- type: product or service
- unit
- default rate
- HSN/SAC optional
- GST rate optional
- active/inactive

Invoice line items must support both:
- selecting saved product/service
- manually typing a custom item

Invoices must store item snapshots, not depend only on product IDs.

## 12. Invoice Features
Invoice types:
- GST invoice
- non-GST invoice

Tax modes:
- No GST
- GST CGST + SGST
- GST IGST

Invoice fields:
- invoice number
- invoice sequence
- financial year
- invoice date
- due date
- customer
- line items
- discount
- loyalty points redemption
- payment method/reference when paid
- notes
- terms
- status: draft, unpaid, paid, cancelled

Line item fields:
- item name
- description optional
- HSN/SAC optional
- quantity
- unit
- rate
- item discount optional
- GST rate optional
- taxable amount
- tax amount
- total

Invoice actions:
- create
- edit draft/unpaid invoice
- duplicate
- mark paid
- cancel
- generate PDF
- print
- download/share PDF

Important rules:
- Products are not required to create invoices.
- GST can be enabled or disabled per invoice.
- Paid invoices should be harder to edit; corrections should preferably use duplicate/cancel workflows.
- Deleted invoice numbers should not be reused by default.

## 13. Quotation Features
Quotation should be included in v1.

Quotation fields:
- quotation number
- quotation sequence
- financial year
- quotation date
- valid until
- customer
- line items
- GST/non-GST mode
- discount
- notes
- terms
- status: draft, sent, accepted, rejected, expired

Quotation actions:
- create
- edit
- duplicate
- generate PDF
- print
- convert to invoice

Convert-to-invoice rules:
- create a new invoice number
- copy customer, items, tax mode, discounts, notes, and terms
- link invoice to source quotation
- mark quotation accepted or converted
- quotation numbers and invoice numbers remain separate

Loyalty points should not be earned from quotations.

## 14. Numbering And Format Settings
Support separate numbering for invoices and quotations.

Settings:
- invoice prefix
- invoice format
- invoice next number
- invoice padding
- quotation prefix
- quotation format
- quotation next number
- quotation padding

Supported tokens:
- `{PREFIX}`
- `{NUMBER}`
- `{YYYY}`
- `{YY}`
- `{FY}`

Examples:
- `INV-0001`
- `INV/2026-27/0001`
- `QT/2026-27/0001`

Rules:
- Show live preview before saving.
- Format changes affect only future records.
- Existing invoice/quotation numbers must not auto-change.
- Check duplicate numbers before save.
- Manual override may be allowed before final save.

## 15. Loyalty Points Features
Loyalty points should be optional and controlled from settings.

Settings:
- enable/disable loyalty points
- earn rule, default: 1 point per ₹100
- redemption value, default: 1 point = ₹1
- maximum redeem percentage per invoice, default: 50%
- minimum redeem points, default: 0

Customer loyalty fields:
- current points balance
- lifetime earned
- lifetime redeemed

Invoice behavior:
- points may be redeemed during invoice creation
- redeemed points become a discount
- points discount applies before GST
- points are earned only when invoice first becomes paid
- if invoice is created as paid, points are awarded immediately
- prevent duplicate awards using a `loyaltyPointsAwarded` flag

Ledger types:
- earned
- redeemed
- adjusted
- reversed

If loyalty is disabled:
- hide loyalty UI from invoice creation
- do not award new points
- keep old ledger/history unchanged

## 16. PDF And Print Requirements
Invoice PDF should include:
- company logo and details
- invoice number/date/due date
- customer details
- GSTIN fields when applicable
- item table
- discount
- loyalty redemption when used
- GST summary when applicable
- total in words
- bank/UPI/payment QR
- terms
- payment status optional

Quotation PDF should include:
- quotation title
- quotation number/date/valid until
- customer details
- item table
- GST/non-GST totals
- terms
- no payment status
- no loyalty earning section

PDF storage rules:
- PDFs are generated locally on the desktop.
- PDFs are not uploaded to Firebase Storage in v1.
- The app may remember the last generated local PDF path, device ID, and generation time.
- If the local file is missing, the app regenerates the PDF from invoice/quotation snapshots stored in Firestore.

## 17. Dashboard And Reports
Dashboard:
- total invoices
- paid amount
- unpaid amount
- this month sales
- recent invoices
- recent quotations
- quick buttons for invoice/quotation/customer

Reports v1:
- sales by date range
- paid/unpaid invoices
- customer-wise sales
- GST summary
- loyalty points summary
- export to PDF or CSV if practical

## 18. Settings
Settings sections:
- company profile
- invoice numbering
- quotation numbering
- GST defaults
- loyalty points
- PDF template basics
- currency, locale, and date format
- local PDF save preferences
- device/license info
- update check
- password change
- backup/export

## 19. Admin/Setup Workflow
For each customer:
1. Customer creates/owns Google/Firebase project.
2. You are temporarily added as admin/editor.
3. You configure Firebase Auth, Firestore, and rules.
4. You create matching Auth user in Control Firebase and customer Firebase.
5. You save customer Firebase config in Control Firebase.
6. You activate license and allowed devices.
7. Customer logs into InvoPrint.

## 20. Implementation Roadmap
Phase 1: Foundation
- Flutter desktop shell
- Control Firebase initialization
- login screen
- license check
- customer Firebase dynamic initialization
- second Auth login
- dashboard shell

Phase 2: Core Data
- company profile
- settings
- customers
- products/services
- Firestore repositories using customer Firebase only

Phase 3: Invoices
- invoice create/edit/list
- manual line items
- GST/non-GST calculations
- numbering
- status flow
- PDF generation and print

Phase 4: Quotations
- quotation create/edit/list
- quotation PDF
- convert quotation to invoice

Phase 5: Loyalty
- loyalty settings
- points ledger
- redeem points on invoice
- auto-award points on paid invoices
- reversal/adjustment support

Phase 6: Polish And Release
- update check
- device limit
- support messages
- error handling
- reports
- packaging Windows desktop installer

## 21. Test Plan
Authentication:
- login succeeds when both Firebase users match
- inactive license blocks access
- invalid customer config shows setup error
- customer Auth mismatch shows support error

Invoices:
- create GST invoice with manual item
- create non-GST invoice without saved product
- create invoice from saved product snapshot
- mark unpaid invoice as paid
- prevent duplicate loyalty awards
- generate PDF correctly

Quotations:
- create GST quotation
- create non-GST quotation
- convert quotation to invoice
- ensure invoice gets new invoice number

Loyalty:
- disabled loyalty hides points
- redeem points applies discount before GST
- paid invoice earns points once
- cancelled paid invoice can reverse points

Settings:
- invoice format preview works
- next number increments correctly
- changed format affects only future invoices
- duplicate number is blocked
- device limit uses active device activation records
- local PDF path can be missing and PDF is regenerated

## 22. Explicit V1 Exclusions
Do not include in v1:
- full accounting ledger
- expense management
- stock/inventory management
- e-way bill
- GST e-invoice API integration
- payment gateway integration
- Firebase Storage
- staff roles and permissions
- WhatsApp automation
- multi-branch management
- custom-token auth

## 23. Assumptions
- This is a new/greenfield Flutter desktop app; the current workspace has no existing project files.
- Windows desktop is the first target.
- Firebase is the primary backend.
- Email/password auth is used for v1.
- Same email/password is created in both Firebase Auth projects.
- Customer Firebase project is owned by the customer.
- Your Firebase is only the control layer.
- Invoice and quotation data belong only in customer Firebase.
- App name is **InvoPrint**.
