# Inventory Magic

Inventory Magic is a Salesforce application for running warehouse inventory. It covers reserving stock against orders, receiving purchase orders, moving stock between locations, adjusting counts and tracking serial numbers. It also has an **offline mode**, so field sales reps can keep creating orders and quotes and reserving stock without an internet connection. This works on desktop and in the **Salesforce mobile app**. Work done offline is saved on the device and syncs back to Salesforce automatically when the connection returns.

It is built with Lightning Web Components (LWC), Aura and Apex as a Salesforce DX project.

---

## Features

### Inventory operations

| Feature | What it does | Main pieces |
| --- | --- | --- |
| **Dashboard** | A single control panel with a sidebar that opens each inventory tool. | `lwc/dashboardApp` |
| **Order reservation** | Reserves inventory for order products. Handles serial-controlled products, and when stock is short it can raise purchase-order lines for the missing quantity. | `lwc/orderProductReserved`, `OrderProductReservedLWC` |
| **Order un-reservation** | Releases reserved quantities and serial numbers back into available stock. | `lwc/orderProductUnReserved`, `orderProductUnReserved` |
| **Receive purchase order** | Receives PO lines into inventory (including serial numbers) and creates shipment records. | `lwc/receivePurchaseOrderLine`, `PurchaseOrderLinesController` |
| **Magic Transfer** | Moves stock reserved for open orders from the main warehouse location to the sales rep's stocking location in one step, and logs transaction history. | `lwc/magicTransfer`, `magicTransferController` |
| **Stock transfer** | Transfers stock between stocking locations, within one warehouse or across warehouses. Creates destination inventory records if they don't exist yet. | `lwc/stockTransfer`, `StockTransferController` |
| **Stock adjustment** | Adjusts on-hand quantities up or down (including serial numbers) and records an audit trail. | `lwc/stockAdjustment`, `StockAdjustmentController` |
| **Bulk purchase orders** | Finds products at or below their reorder quantity and creates purchase orders in bulk. A batch job groups the lines by supplier. | `lwc/createBulkPO`, `createBulkPOController`, `BulkPurchaseOrderBatch` |
| **Invoicing** | Creates invoices and invoice lines from orders, with due dates worked out from payment terms such as "Net 30". | `createInvoice_LineItemHandler` |
| **Serial number tracking** | Modals for capturing serial numbers wherever stock moves. | `lwc/addSerialModal`, `lwc/addSerialNumberModal` |
| **Reusable lookup** | A generic, filterable record lookup used across the components. | `lwc/lwcLookup`, `LwcLookupController` |

### Offline mode

The `offlineCmp` component lets a user keep working when the device has no connection, both in a desktop browser and in the **Salesforce mobile app** (iOS and Android):

- **Local cache.** While online, the component downloads customer accounts, active products, warehouses, stocking locations, inventory, serial numbers and order items awaiting reservation, and stores them in `localStorage`. That is the browser's storage on desktop and the device's own storage in the mobile app, so a rep can go out in the field with the data already on the phone.
- **Work offline.** Users can do the following against the cached data:
  - create **orders** with order products (`createOrderOffline`)
  - create **quotes** with quote lines (`quoteCmpOffline`)
  - **reserve order items**, including picking serial numbers (`reserveOrderItemsOffline`, `addSerialModalOffline`)
  - browse cached records (`recordView`, `recordViewList`)
- **Automatic sync.** When the browser comes back online, queued orders, quotes and reservations are pushed to Salesforce, and then the local cache is refreshed. Users can also sync manually, and the screen shows the time of the last sync.
- **Safe writes.** Each sync runs in a single transaction with a savepoint, so a failure rolls back the whole batch. After offline orders sync, the warehouse managers get an email.

Server-side logic: `offlineController.cls`.

### Automation

| Trigger | Object | Purpose |
| --- | --- | --- |
| `InventoryTrigger` | `IMagic__Inventory__c` | Rolls up quantity on hand, quantity reserved, cost and sale price to the product. |
| `POLineTrigger` | `Lodestone__Purchase_Order_Line__c` | Rolls up the total quantity on purchase orders to the product. |
| `orderProductTrigger` | `OrderItem` | Fills in the default warehouse and stocking location on new order products. |

You can turn each trigger on or off without deploying code, using the `LodestoneGroup_DMLConfig__mdt` custom metadata type.

---

## Project structure

```
force-app/main/default/
├── lwc/              Lightning Web Components (UI, including the offline components)
├── aura/             Aura components and apps that host the tools in Visualforce
├── classes/          Apex controllers, trigger handlers, batch job and test classes
├── triggers/         Apex triggers
├── pages/            Visualforce pages (Magic Transfer, Stock Transfer, Stock Adjustment, ...)
└── staticresources/  Images and animations used by the UI
config/               Scratch org definition
manifest/             package.xml for metadata retrieve/deploy
scripts/              Sample anonymous Apex and SOQL scripts
```

---

## Prerequisites

> **Important:** This repository holds only the **code**: Apex, LWC, Aura, Visualforce and static resources. The **data model is not included.** The target org must already contain these objects and fields:

- **Inventory Magic objects** (`IMagic__` namespace): Warehouse, Stocking Location, Inventory, Inventory Detail (serial numbers), Transaction History, Stock Transfer and its lines, Stock Adjustment and its lines, and Magic Transfer and its lines.
- **Lodestone objects** (`Lodestone__` namespace): Purchase Order, Purchase Order Line, Invoice, Invoice Line, plus the product fields for supplier and sale price.
- **Org-level metadata**: the `LodestoneGroup_DMLConfig__mdt` custom metadata type with one record, `Shipment__c`, and the custom `Warehouse__c` and `Stocking_Location__c` lookup fields on `Order`.
- Standard Salesforce objects: Account (with a `Customer` record type), Product2 (with a `Serial Control` record type), Order and OrderItem, Opportunity, Quote, and the standard price book.

Tools:

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- Node.js 18 or later (only needed for linting, formatting and Jest tests)
- VS Code with the Salesforce Extension Pack (recommended)

---

## Getting started

```bash
# 1. Clone the repository
git clone https://github.com/SyedKashan70/InventoryMagic.git
cd InventoryMagic

# 2. Install dev tooling (ESLint, Prettier, Jest, Husky)
npm install

# 3. Authorize your target org
sf org login web --alias inventory-magic

# 4. Deploy the source
sf project deploy start --source-dir force-app --target-org inventory-magic

# 5. Run the Apex tests
sf apex run test --target-org inventory-magic --test-level RunLocalTests --wait 10
```

After you deploy, add **`dashboardApp`** or **`offlineCmp`** to a Lightning App page, Home page or tab with Lightning App Builder. `orderProductReserved` and `orderProductUnReserved` are built as quick actions on the Order record page.

To use offline mode on mobile, add the Lightning page or tab that contains `offlineCmp` to the Salesforce mobile app navigation (**Setup → Mobile Apps → Salesforce Navigation**). Then open it once while online so the data is cached on the device.

---

## Development

| Command | Description |
| --- | --- |
| `npm run lint` | Lint the LWC and Aura JavaScript with ESLint |
| `npm run prettier` | Format all source files |
| `npm run prettier:verify` | Check formatting without changing files |
| `npm test` | Run the LWC Jest unit tests |
| `npm run test:unit:coverage` | Run the Jest tests with a coverage report |

A Husky pre-commit hook runs Prettier and ESLint on staged files.

Each Apex class comes with a matching `*Test.cls`, and test data is built by `D_TestDataFactory`.

---

## Tech stack

- **Salesforce Platform**: API version 62.0
- **Apex**: controllers, trigger handlers, a Batch Apex job
- **Lightning Web Components** and **Aura**
- **Visualforce**: Lightning Out host pages
- **`localStorage`** for offline caching on desktop and in the Salesforce mobile app

---

## Author

**Syed Kashan**
