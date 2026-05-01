# InvoPrint Technical Design Document

## Summary
Create `InvoPrint_TDD.md` as the full technical design document for the Flutter desktop app. The app will use BLoC, feature-based clean architecture, SOLID/OOP principles, centralized theming, Control Firebase for license/config/update management, and Customer Firebase for business data.

V1 will **not use Firebase Storage**. Company logo and payment QR will be stored as small base64 strings in Firestore. Invoice and quotation PDFs will be generated locally on the desktop and saved locally only when the user chooses.

## Architecture Decisions
- State management: `flutter_bloc`
- Architecture: feature-based clean architecture
- Backend: Firebase Auth + Cloud Firestore only
- Storage: no Firebase Storage in v1
- PDF handling: generate locally from Firestore data
- App data ownership: customer business data stays in customer Firebase
- Auth: one visible login screen, two internal Firebase Auth sessions
- Theme: centralized global theme tokens
- Models: immutable domain models with Firestore DTOs
- Testing: unit tests for business logic, BLoC tests for flows, widget tests for key forms

## Recommended TDD File Content

```md
# InvoPrint Technical Design Document

## 1. Product Overview
InvoPrint is a Flutter desktop invoice application for small Indian businesses. It supports GST and non-GST invoices, quotations, customer management, product/service shortcuts, payment tracking, loyalty points, PDF generation, and print workflows.

The app uses Firebase in a customer-owned cloud model. Your Firebase project acts as the control layer for license, update, device, and customer config management. Each customer has their own Firebase project for business data.

## 2. Core Technical Goals
- Build a clean production-level Flutter desktop app.
- Use BLoC for predictable state management.
- Use feature-based folder structure.
- Apply OOP and SOLID principles without overengineering.
- Keep UI independent from Firebase implementation.
- Keep all theme colors, spacing, and text styles centralized.
- Use strongly typed models and Firestore schemas.
- Generate invoice and quotation PDFs locally.
- Avoid Firebase Storage in v1.

## 3. Tech Stack
- Flutter desktop, Windows first
- Dart
- flutter_bloc
- equatable
- firebase_core
- firebase_auth
- cloud_firestore
- go_router
- get_it
- freezed
- json_serializable
- intl
- pdf
- printing
- mocktail
- bloc_test

Optional:
- flutter_secure_storage for local device/session metadata

## 4. Firebase Architecture

### 4.1 Control Firebase
Control Firebase is owned by the software provider.

Stores:
- user login
- license status
- customer profile
- device activation records
- customer Firebase config
- latest app version
- update/download link
- support status

Does not store:
- invoices
- quotations
- customers
- products
- loyalty data
- business reports

### 4.2 Customer Firebase
Customer Firebase is owned by the customer.

Stores:
- company profile
- app settings
- customers
- products/services
- invoices
- quotations
- loyalty ledger
- reports data

V1 services enabled:
- Firebase Auth
- Cloud Firestore

V1 services not used:
- Firebase Storage

## 5. Authentication Design
The app shows one login screen but uses two Firebase Auth sessions internally.

Flow:
1. User enters email and password.
2. App signs into Control Firebase Auth.
3. App validates license and device permission.
4. App fetches customer Firebase config from Control Firestore.
5. App initializes customer Firebase dynamically.
6. App signs into Customer Firebase Auth with the same email/password.
7. App opens dashboard after both sessions succeed.

Failure states:
- Invalid control login
- Inactive/suspended license
- Device limit exceeded
- Missing customer Firebase config
- Invalid customer Firebase config
- Customer Firebase Auth password mismatch

## 6. Firebase App Manager
Create a central service to manage Firebase instances.

Responsibilities:
- initialize Control Firebase
- expose Control Auth and Firestore
- fetch customer Firebase config
- initialize Customer Firebase
- expose Customer Auth and Firestore
- prevent business repositories from accidentally using Control Firestore

Conceptual API:
```dart
abstract class FirebaseAppManager {
  Future<void> initializeControlApp();
  Future<void> initializeCustomerApp(CustomerFirebaseConfig config);

  FirebaseAuth get controlAuth;
  FirebaseFirestore get controlDb;

  FirebaseAuth get customerAuth;
  FirebaseFirestore get customerDb;
}
```

## 7. Folder Structure
Use feature-based clean architecture.

```text
lib/
  main.dart
  app/
    invo_print_app.dart
    router/
      app_router.dart
      route_names.dart
    di/
      service_locator.dart
    theme/
      app_theme.dart
      app_colors.dart
      app_text_styles.dart
      app_spacing.dart
      app_sizes.dart
  core/
    constants/
    errors/
      app_exception.dart
      failure.dart
    firebase/
      firebase_app_manager.dart
    formatting/
      currency_formatter.dart
      date_formatter.dart
      number_to_words.dart
    utils/
    widgets/
      app_button.dart
      app_text_field.dart
      app_dropdown.dart
      app_dialog.dart
      app_shell.dart
    domain/
      value_objects/
        money.dart
        percentage.dart
        gstin.dart
  features/
    auth/
    dashboard/
    company/
    customers/
    products/
    invoices/
    quotations/
    loyalty/
    reports/
    settings/
    updates/
```

Each feature:

```text
features/invoices/
  data/
    datasources/
    models/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
    services/
  presentation/
    bloc/
    pages/
    widgets/
```

## 8. OOP And SOLID Rules
Encapsulation:
- Keep calculations inside services/value objects.
- Do not calculate totals inside widgets.

Abstraction:
- Use repository interfaces in domain layer.
- Firebase implementations stay in data layer.

Inheritance:
- Use lightly.
- Prefer composition and interfaces.

Polymorphism:
- Use repository contracts and multiple implementations for real app/tests.

SOLID:
- SRP: each class has one clear responsibility.
- OCP: add new tax/PDF behaviors without rewriting UI.
- LSP: repository implementations must honor the same contract.
- ISP: keep interfaces small.
- DIP: BLoCs/use cases depend on abstractions.

Avoid:
- deep inheritance trees
- generic base repositories before needed
- unnecessary abstractions for simple UI behavior

## 9. Theme And Global Design System
Create centralized design tokens.

Files:
```text
lib/app/theme/app_colors.dart
lib/app/theme/app_text_styles.dart
lib/app/theme/app_spacing.dart
lib/app/theme/app_sizes.dart
lib/app/theme/app_theme.dart
```

Rules:
- No hardcoded colors in screens.
- No repeated raw spacing values in screens.
- Change primary color once and it reflects across the app.
- Shared widgets must use app theme tokens.

Desktop UI:
- left sidebar navigation
- top header
- content area
- data tables
- compact forms
- clear action buttons
- dialogs for confirmation
- no marketing-style landing page inside the app

## 10. Control Firebase Schema

### users/{uid}
```json
{
  "email": "client@example.com",
  "customerId": "cust_001",
  "licenseId": "lic_001",
  "displayName": "ABC Traders",
  "role": "customer",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### licenses/{licenseId}
```json
{
  "customerId": "cust_001",
  "status": "active",
  "allowedDevices": 2,
  "activatedDevices": 1,
  "purchaseAmount": 6000,
  "currencyCode": "INR",
  "supportStatus": "active",
  "supportEndsAt": "timestamp",
  "minorUpdatesUntil": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### deviceActivations/{deviceId}
```json
{
  "customerId": "cust_001",
  "licenseId": "lic_001",
  "userId": "uid_001",
  "deviceId": "hashed-device-id",
  "deviceName": "Office PC",
  "platform": "windows",
  "appVersion": "1.0.0",
  "firstActivatedAt": "timestamp",
  "lastSeenAt": "timestamp",
  "isActive": true
}
```

### customerConfigs/{customerId}
```json
{
  "projectId": "abc-traders-prod",
  "apiKey": "...",
  "authDomain": "...",
  "storageBucket": "",
  "messagingSenderId": "...",
  "appId": "...",
  "enabled": true,
  "configVersion": 1,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Note:
- `storageBucket` may be empty or unused in v1.
- Keep field if future Firebase Storage support is added.

### appVersions/windows
```json
{
  "latestVersion": "1.0.0",
  "minimumSupportedVersion": "1.0.0",
  "downloadUrl": "https://...",
  "releaseNotes": "Initial release",
  "forceUpdate": false,
  "publishedAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## 11. Customer Firebase Schema

### company/profile
```json
{
  "businessName": "ABC Traders",
  "contactPerson": "Rahul",
  "phone": "9999999999",
  "email": "abc@example.com",
  "website": "optional",
  "address": "Full address",
  "state": "Kerala",
  "gstin": "optional",
  "pan": "optional",
  "logoBase64": "optional-small-base64",
  "logoMimeType": "image/png",
  "paymentQrBase64": "optional-small-base64",
  "paymentQrMimeType": "image/png",
  "signatureBase64": "optional-small-base64",
  "signatureMimeType": "image/png",
  "bankName": "optional",
  "accountNumber": "optional",
  "ifsc": "optional",
  "upiId": "optional",
  "termsTitle": "Terms & Conditions",
  "defaultTerms": "optional",
  "authorizedSignatoryName": "optional",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Logo/QR rules:
- Store only small compressed images.
- Recommended max size: 150 KB each after compression.
- Validate file type and size before saving.
- Use PNG/JPEG only.
- PDF generator reads base64 and embeds image locally.

### settings/app
```json
{
  "gstEnabledByDefault": true,
  "defaultTaxMode": "cgst_sgst",
  "currencyCode": "INR",
  "currencySymbol": "₹",
  "locale": "en_IN",
  "dateFormat": "dd/MM/yyyy",
  "invoicePrefix": "INV",
  "invoiceFormat": "{PREFIX}/{FY}/{NUMBER}",
  "invoiceNextNumber": 1,
  "invoicePadding": 4,
  "quotationPrefix": "QT",
  "quotationFormat": "{PREFIX}/{FY}/{NUMBER}",
  "quotationNextNumber": 1,
  "quotationPadding": 4,
  "loyaltyEnabled": false,
  "earnPoints": 1,
  "earnPointsPerAmount": 100,
  "pointValueAmount": 1,
  "maxRedeemPercent": 50,
  "minimumRedeemPoints": 0,
  "defaultPdfSaveFolder": "optional-local-path",
  "autoOpenPdfAfterGenerate": true,
  "pdfPageSize": "a4",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### customers/{customerId}
```json
{
  "name": "Customer Name",
  "phone": "9999999999",
  "email": "customer@example.com",
  "billingAddress": "Address",
  "shippingAddress": "optional",
  "gstin": "optional",
  "state": "Kerala",
  "defaultDiscountType": "percentage",
  "defaultDiscountValue": 0,
  "loyaltyEnabled": true,
  "loyaltyPointsBalance": 0,
  "lifetimePointsEarned": 0,
  "lifetimePointsRedeemed": 0,
  "totalBilled": 0,
  "totalPaid": 0,
  "outstandingAmount": 0,
  "lastInvoiceAt": "timestamp",
  "notes": "optional",
  "isActive": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### products/{productId}
```json
{
  "name": "Website Design",
  "description": "optional",
  "type": "service",
  "unit": "service",
  "defaultRate": 15000,
  "hsnSac": "998314",
  "gstRate": 18,
  "isActive": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### invoices/{invoiceId}
```json
{
  "invoiceNumber": "INV/2026-27/0001",
  "invoiceSequence": 1,
  "financialYear": "2026-27",
  "invoiceDate": "timestamp",
  "dueDate": "timestamp",
  "customerId": "cust_123",
  "customerSnapshot": {},
  "companySnapshot": {},
  "items": [],
  "taxMode": "cgst_sgst",
  "status": "unpaid",
  "subtotal": 10000,
  "discountType": "none",
  "discountValue": 0,
  "discountTotal": 0,
  "discountReason": "optional",
  "pointsRedeemed": 0,
  "pointsDiscountAmount": 0,
  "taxableAmount": 10000,
  "cgstAmount": 900,
  "sgstAmount": 900,
  "igstAmount": 0,
  "grandTotal": 11800,
  "amountPaid": 0,
  "paymentMethod": "cash",
  "paymentReference": "optional",
  "paymentNotes": "optional",
  "paidAt": null,
  "loyaltyPointsAwarded": false,
  "pointsEarned": 0,
  "notes": "optional",
  "terms": "optional",
  "lastGeneratedPdfPath": "optional",
  "lastGeneratedPdfAt": "timestamp",
  "lastGeneratedPdfDeviceId": "device-id",
  "sourceQuotationId": null,
  "sourceQuotationNumber": null,
  "createdBy": "uid",
  "updatedBy": "uid",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### invoice item shape
```json
{
  "productId": null,
  "name": "Custom Service",
  "description": "optional",
  "hsnSac": "optional",
  "quantity": 1,
  "unit": "service",
  "rate": 10000,
  "discountType": "none",
  "discountValue": 0,
  "gstRate": 18,
  "taxableAmount": 10000,
  "cgstAmount": 900,
  "sgstAmount": 900,
  "igstAmount": 0,
  "total": 11800
}
```

### quotations/{quotationId}
```json
{
  "quotationNumber": "QT/2026-27/0001",
  "quotationSequence": 1,
  "financialYear": "2026-27",
  "quotationDate": "timestamp",
  "validUntil": "timestamp",
  "customerId": "cust_123",
  "customerSnapshot": {},
  "companySnapshot": {},
  "items": [],
  "taxMode": "none",
  "status": "draft",
  "subtotal": 10000,
  "discountType": "none",
  "discountValue": 0,
  "discountTotal": 0,
  "discountReason": "optional",
  "taxableAmount": 10000,
  "cgstAmount": 0,
  "sgstAmount": 0,
  "igstAmount": 0,
  "grandTotal": 10000,
  "notes": "optional",
  "terms": "optional",
  "lastGeneratedPdfPath": "optional",
  "lastGeneratedPdfAt": "timestamp",
  "lastGeneratedPdfDeviceId": "device-id",
  "convertedInvoiceId": null,
  "convertedInvoiceNumber": null,
  "convertedAt": null,
  "createdBy": "uid",
  "updatedBy": "uid",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### loyaltyLedger/{ledgerId}
```json
{
  "customerId": "cust_123",
  "invoiceId": "inv_001",
  "invoiceNumber": "INV/2026-27/0001",
  "type": "earned",
  "direction": "credit",
  "points": 50,
  "amountValue": 50,
  "balanceAfter": 250,
  "note": "Points earned from INV/2026-27/0001",
  "createdBy": "uid",
  "createdAt": "timestamp"
}
```

## 12. PDF And Local File Strategy
V1 does not upload PDFs to Firebase.

Behavior:
- PDF is generated locally from Firestore invoice/quotation data.
- User can print immediately.
- User can save the PDF to a local folder.
- App may store `lastGeneratedPdfPath`, `lastGeneratedPdfAt`, and `lastGeneratedPdfDeviceId` for convenience.
- If local file is missing, app regenerates PDF from saved data.

Important:
- Store `companySnapshot` in invoice/quotation at creation time.
- Store `customerSnapshot` in invoice/quotation at creation time.
- Store item snapshots in invoice/quotation.
- This allows old PDFs to be regenerated even if company/customer/product data changes later.

## 13. Domain Models
Entities:
- AppUser
- License
- CustomerFirebaseConfig
- CompanyProfile
- AppSettings
- Customer
- ProductService
- Invoice
- InvoiceItem
- Quotation
- QuotationItem
- LoyaltyLedgerEntry
- Money
- Discount
- TaxBreakdown
- NumberingSettings

Enums:
```text
LicenseStatus: active, inactive, suspended, expired
TaxMode: none, cgstSgst, igst
InvoiceStatus: draft, unpaid, paid, cancelled
QuotationStatus: draft, sent, accepted, rejected, expired, converted
ProductType: product, service
DiscountType: none, percentage, fixed
LoyaltyLedgerType: earned, redeemed, adjusted, reversed
```

Rules:
- Domain entities must not import Firebase SDK.
- Firestore DTOs handle serialization.
- Use immutable models.
- Use snapshots for historical invoice/quotation accuracy.
- UI must not perform business calculations.

## 14. BLoC Design
Recommended BLoCs:
- AuthBloc
- DashboardBloc
- CompanyBloc
- CustomerBloc
- ProductBloc
- InvoiceListBloc
- InvoiceEditorBloc
- QuotationListBloc
- QuotationEditorBloc
- LoyaltyBloc
- SettingsBloc
- UpdateBloc

AuthBloc:
- login to Control Firebase
- validate license
- fetch customer Firebase config
- initialize Customer Firebase
- login to Customer Firebase
- emit authenticated/setup error states

InvoiceEditorBloc:
- select customer
- add manual line item
- add saved product line item
- calculate totals
- apply discount
- redeem points
- save invoice
- mark invoice paid
- award loyalty points if eligible
- generate local PDF

QuotationEditorBloc:
- create/edit quotation
- calculate totals
- generate local PDF
- convert quotation to invoice

## 15. Business Logic Services
Services:
- InvoiceCalculator
- QuotationCalculator
- GstCalculator
- LoyaltyCalculator
- NumberingService
- PdfInvoiceBuilder
- PdfQuotationBuilder
- LocalPdfFileService
- DeviceIdService

Rules:
- GST disabled means no GST totals.
- CGST/SGST splits GST equally.
- IGST applies full GST amount.
- Discounts and loyalty redemption apply before GST.
- Points are earned only when invoice first becomes paid.
- Quotations do not earn loyalty points.
- Products are optional helpers only.

## 16. Repository Contracts
Domain layer interfaces:
- AuthRepository
- LicenseRepository
- CustomerConfigRepository
- CompanyRepository
- SettingsRepository
- CustomerRepository
- ProductRepository
- InvoiceRepository
- QuotationRepository
- LoyaltyRepository
- PdfRepository
- UpdateRepository

Rules:
- Control repositories use Control Firestore.
- Business repositories use Customer Firestore.
- Repositories return domain entities or failures.
- Widgets never call Firestore directly.

## 17. Navigation
Routes:
```text
/login
/dashboard
/customers
/products
/invoices
/invoices/new
/invoices/:id
/quotations
/quotations/new
/quotations/:id
/loyalty
/reports
/settings
/settings/company
/settings/numbering
/settings/loyalty
/settings/license
```

Auth guard:
- unauthenticated users go to `/login`
- authenticated users go to `/dashboard`
- setup/config errors go to setup error page

## 18. Main UI Modules
Dashboard:
- paid amount
- unpaid amount
- invoice count
- quotation count
- recent invoices
- recent quotations
- quick actions

Invoices:
- list/search/filter
- create/edit
- GST/non-GST
- manual items
- saved product items
- PDF/print
- paid/unpaid/cancelled status

Quotations:
- list/search/filter
- create/edit
- PDF/print
- convert to invoice

Customers:
- CRUD
- view outstanding
- view points
- view invoice history

Products:
- optional item shortcuts
- product/service type
- default GST/rate/unit

Loyalty:
- customer points
- ledger history
- adjustment/reversal

Settings:
- company profile
- logo base64
- payment QR base64
- numbering
- GST defaults
- loyalty settings
- license/device info
- password change
- update check

## 19. Testing Strategy
Unit tests:
- GST calculation
- non-GST calculation
- item discount
- invoice-level discount
- loyalty redemption before GST
- points earning on paid invoice
- no duplicate points award
- numbering format preview
- quotation-to-invoice conversion
- base64 logo/QR size validation

BLoC tests:
- login success
- inactive license
- missing customer config
- customer Auth failure
- invoice editor recalculates totals
- mark paid awards points once
- loyalty disabled blocks redemption
- PDF generation failure state

Widget tests:
- login form validation
- invoice manual item entry
- GST/non-GST switching
- loyalty hidden when disabled
- numbering preview
- logo/QR upload validation

Acceptance tests:
- login once and reach dashboard
- create non-GST invoice without saved product
- create GST invoice with manual item
- create quotation and convert to invoice
- enable loyalty and earn points after payment
- generate invoice PDF locally
- regenerate PDF when local file path is missing

## 20. Implementation Phases
Phase 1: Flutter Foundation
- Create Flutter desktop project.
- Add dependencies.
- Add app theme.
- Add router.
- Add dependency injection.
- Add core error/failure classes.
- Add base widgets.

Phase 2: Firebase Auth Foundation
- Initialize Control Firebase.
- Build FirebaseAppManager.
- Implement AuthBloc.
- Fetch customer config.
- Initialize Customer Firebase.
- Login to both Auth sessions.

Phase 3: Settings And Company
- Build company profile model/schema.
- Add logo/payment QR base64 validation.
- Build settings model/schema.
- Build settings screens.

Phase 4: Customers And Products
- Build customer CRUD.
- Build product/service CRUD.
- Add search/filter.

Phase 5: Invoice Engine
- Build invoice models.
- Build calculators.
- Build numbering service.
- Build invoice editor/list.
- Support GST/non-GST.
- Support manual and saved items.
- Generate and save PDF locally.

Phase 6: Quotations
- Build quotation models.
- Build quotation editor/list.
- Generate quotation PDF locally.
- Convert quotation to invoice.

Phase 7: Loyalty
- Build loyalty settings.
- Build ledger.
- Redeem points.
- Award points on paid invoice.
- Add adjustment/reversal support.

Phase 8: Reports And Release
- Dashboard summaries.
- Basic reports.
- Update check.
- Device/license screen.
- Windows packaging.

## 21. Explicit Technical Rules
- Do not use Firebase Storage in v1.
- Do not store PDFs in Firestore.
- Do not store large images in Firestore.
- Logo and QR must be small compressed base64 strings.
- Do not access Firestore from widgets.
- Do not calculate invoice totals inside widgets.
- Do not hardcode theme colors in screens.
- Do not store business data in Control Firebase.
- Do not require saved products to create invoices.
- Do not award loyalty points for quotations.
- Do not reuse deleted invoice numbers by default.
- Do not freely edit paid invoices.
- Do not create deep inheritance trees.
- Do not add generic abstractions before they are useful.

## 22. Assumptions
- App name is InvoPrint.
- Windows desktop is first target.
- BLoC is the standard state management.
- Feature-based clean architecture is used.
- Firebase Auth email/password is used for v1.
- Same email/password exists in Control Firebase and Customer Firebase.
- Customer Firebase project is owned by the customer.
- Customer business data stays only in Customer Firebase.
- Firebase Storage is deferred to a future version.
- PDFs are generated and stored locally.
- Logo/payment QR are stored as small base64 strings in Firestore.
```

## Test Plan For This Documentation Change
- Confirm PRD and TDD both say Firebase Storage is excluded from v1.
- Confirm schemas use `logoBase64`, `paymentQrBase64`, and local PDF metadata instead of Storage URLs.
- Confirm invoice and quotation schemas include snapshots required for local PDF regeneration.
- Confirm implementation phases do not include Storage setup.
- Confirm technical rules explicitly block large Firestore image payloads.

## Assumptions
- The file should be named `InvoPrint_TDD.md`.
- The existing `InvoPrint_PRD.md` remains the product document.
- This new TDD is a separate technical document.
- “TDD” means Technical Design Document here, with testing strategy included.
