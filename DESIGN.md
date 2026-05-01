# InvoPrint Design System

## 1. Design Direction
InvoPrint should feel like a clean, modern desktop business tool: minimal, calm, fast to scan, and professional. Use gradients as restrained accents, not as full-screen decoration.

Style keywords:
- Minimal
- Professional
- Compact
- Trustworthy
- Light desktop SaaS
- Subtle gradient accents

Do not design it like a marketing landing page. The first screen after login is the working dashboard.

## 2. Visual Principle
The UI should help users create invoices quickly without visual noise.

Use:
- clean white/off-white surfaces
- strong readable typography
- compact tables
- clear status chips
- restrained borders
- subtle shadows
- gradient only for important brand surfaces and primary actions

Avoid:
- heavy decorative backgrounds
- colorful cards everywhere
- oversized hero typography
- nested cards
- excessive rounded corners
- one-color monotone layouts

## 3. Color Tokens
All colors must come from global theme variables. No raw colors should be used inside screens.

Runtime theme rule:
- Theme mode and primary color are controlled globally by `ThemeCubit`.
- Screens, feature widgets, shells, cards, dialogs, and previews must use `AppColors` or `Theme.of(context)`.
- Do not use raw `Color(0x...)`, `Colors.white`, `Colors.black`, or one-off opacity shadows inside feature UI. Add a token to `AppColors` first.
- Do not make shell colors independent from content colors. Sidebar, top bar, content, cards, inputs, and previews must all update when theme mode changes.
- Primary/accent color must come from the saved `primaryColorHex`; do not hardcode violet/blue inside widgets.
- Existing exceptions are only allowed inside `AppColors` and theme construction files.

Recommended palette:

```text
Primary:        #2563EB
Primary Dark:   #1E40AF
Primary Light:  #DBEAFE
Secondary:      #0F766E
Accent:         #F59E0B

Background:     #F8FAFC
Surface:        #FFFFFF
Surface Soft:   #F1F5F9
Border:         #E2E8F0

Text Primary:   #0F172A
Text Secondary: #475569
Text Muted:     #94A3B8

Success:        #16A34A
Warning:        #D97706
Error:          #DC2626
Info:           #0284C7
Neutral:        #64748B
```

Gradient tokens:

```text
Primary Gradient:  #2563EB -> #0F766E
Soft Gradient:     #EFF6FF -> #F0FDFA
Button Gradient:   #2563EB -> #1D4ED8
Header Gradient:   #F8FAFC -> #EFF6FF
```

Gradient rules:
- Use gradient on primary button hover/active state.
- Use soft gradient in the login panel/sidebar header/dashboard header only.
- Do not use gradient blobs, orbs, or decorative background shapes.
- Tables, forms, and settings pages should stay mostly flat and white.

## 4. Typography
Use a clean sans-serif font. Good choices:
- Inter
- Roboto
- Noto Sans

Type scale:

```text
Display/Page Title: 24px / 32px / 600
Section Title:      18px / 26px / 600
Card Metric:        22px / 30px / 700
Body:               14px / 22px / 400
Body Strong:        14px / 22px / 600
Caption:            12px / 18px / 400
Table Header:       12px / 16px / 600
Button:             14px / 20px / 600
```

Rules:
- No negative letter spacing.
- Do not scale fonts with viewport width.
- Keep table text compact and readable.
- Use page-scale headings only for page headers.

## 5. Spacing And Shape
Spacing tokens:

```text
xs: 4
sm: 8
md: 12
lg: 16
xl: 24
2xl: 32
3xl: 48
```

Radius:

```text
Small: 4
Medium: 6
Large: 8
Dialog: 8
```

Rules:
- Cards and panels should use max 8px radius.
- Buttons should use 6px radius.
- Inputs should use 6px radius.
- Do not use pill shapes except status chips.

## 6. Layout System
Use a desktop app shell:

```text
Left Sidebar: 240px
Top Header:   64px
Content Max:  flexible, full available width
Page Padding: 24px
```

App shell:
- fixed left sidebar
- top header with current business, license/update indicator, and user menu
- main content scroll area
- page header with title and primary action

Sidebar:
- InvoPrint logo/name
- Dashboard
- Invoices
- Quotations
- Customers
- Products/Services
- Loyalty
- Reports
- Settings
- License & Updates

Sidebar active item:
- soft primary background
- primary text
- small left accent bar or icon color

## 7. Components

### Buttons
Primary button:
- gradient background
- white text
- icon + label when helpful
- used for main page actions

Secondary button:
- white background
- border
- primary or text color

Destructive button:
- red text or red background for confirmed destructive actions

Icon buttons:
- use icons for print, PDF, edit, duplicate, delete, refresh, search
- include tooltip

### Inputs
Use consistent input fields:
- label above field
- helper/error text below
- 40px height for normal fields
- 36px height for compact table filters

### Tables
Tables are the main working surface.

Table rules:
- sticky header if practical
- compact rows
- action menu at right
- status chip column
- empty state when no data
- search and filters above table

### Status Chips
Use consistent colors:

```text
Paid:       Success
Unpaid:     Warning
Draft:      Neutral
Cancelled:  Error
Sent:       Info
Accepted:   Success
Rejected:   Error
Expired:    Neutral
Converted:  Info
```

### Dialogs
Use dialogs for:
- delete/archive confirmation
- mark paid
- adjust loyalty points
- password change
- PDF preview confirmation

Dialogs:
- max width 480px for simple dialogs
- max width 720px for form dialogs
- 8px radius
- clear primary/secondary actions

## 8. Page Designs

### Login
Minimal centered login panel with a soft gradient brand strip.

Elements:
- InvoPrint logo/name
- tagline: GST invoices, quotations, and loyalty billing
- email field
- password field
- login button
- support contact text
- error banner for license/config/device/password mismatch errors

### Dashboard
Use compact metric panels:
- This month sales
- Paid amount
- Unpaid amount
- Total invoices
- Open quotations
- Loyalty points issued

Below metrics:
- Recent invoices table
- Recent quotations table
- Quick actions row

Use a soft header gradient behind the page title area only.

### Invoices
Primary working table page.

Header:
- title: Invoices
- New Invoice button

Filters:
- search
- status
- date range
- customer
- tax mode

Table:
- invoice number
- date
- customer
- tax mode
- total
- paid amount
- status
- actions

### Create/Edit Invoice
Use a full page form, not a small modal.

Top summary bar:
- invoice number
- status
- grand total
- Save/Print actions

Sections:
- invoice details
- customer
- line items
- discount
- loyalty redemption
- payment details
- notes and terms
- totals panel

Line items should look like a spreadsheet-style editable table.

Totals panel should be fixed on the right on wide desktop screens and below content on narrower screens.

### Quotations
Same structure as invoices but with quotation statuses.

Key action:
- Convert to Invoice

### Create/Edit Quotation
Same layout as invoice editor, but remove:
- payment section
- loyalty redemption
- paid status actions

Add:
- valid until
- convert to invoice action

### Customers
Customer table:
- name
- phone
- email
- GSTIN
- state
- outstanding amount
- loyalty points
- last invoice date
- actions

Customer details should use tabs:
- Overview
- Invoices
- Quotations
- Loyalty Ledger
- Notes

### Products/Services
Simple table with side panel or form page.

Fields:
- name
- type
- unit
- default rate
- HSN/SAC
- GST rate
- active status

### Loyalty
Use two main areas:
- customer points summary table
- loyalty ledger table

Add adjustment dialog:
- customer
- credit/debit
- points
- note

### Reports
Use report filters at top:
- date range
- customer optional
- tax mode optional

Report tabs:
- Sales
- GST Summary
- Customer Sales
- Paid/Unpaid
- Loyalty

Use simple charts only if they remain readable. Tables are more important.

### Settings
Settings should use internal sidebar/tabs:
- Company Profile
- Invoice Numbering
- Quotation Numbering
- GST Defaults
- Loyalty Points
- PDF Template
- Local PDF
- Password
- License & Device

Settings pages should be form-focused, not card-heavy.

### License & Updates
Show:
- license status
- support status
- support end date
- allowed devices
- active devices table
- current app version
- latest app version
- update/download link

## 9. PDF Template Customization
V1 supports template customization, not a full drag-drop template builder.

Built-in templates:
- Classic
- Modern
- Compact

Customizable options:
- default invoice template
- default quotation template
- accent color
- show/hide logo
- show/hide signature
- show/hide payment QR
- show/hide bank details
- show/hide terms
- footer note

PDF preview should be available from settings.

## 10. Empty, Loading, And Error States
Every list page needs:
- loading state
- empty state
- error state

Error messages should be plain and support-friendly.

Examples:
- License inactive. Please contact support.
- Device limit reached. Remove an old device or contact support.
- Business cloud login failed. Your app password may be out of sync.
- Customer cloud configuration is missing.
- PDF file was not found locally. Regenerate the PDF.

## 11. Accessibility And Usability
Requirements:
- keyboard focus states
- visible hover states
- readable contrast
- tooltips for icon-only buttons
- no text overflow in buttons or chips
- confirmation before destructive actions
- form validation messages near fields

Desktop minimum target:
- 1024px width and above

## 12. Implementation Rules
- All colors come from `AppColors`.
- All spacing comes from `AppSpacing`.
- All text styles come from `AppTextStyles`.
- Shared UI components live in `core/widgets`.
- Feature-specific widgets stay inside their feature folder.
- Screens must not hardcode raw colors, shadows, or font sizes unless added to the design system first.
- Gradients must come from named theme tokens.
