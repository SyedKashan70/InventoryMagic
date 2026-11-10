public class BulkPurchaseOrderBatch implements Database.Batchable<SObject>, Database.Stateful {
    private String orderQuantitiesJson;
    private String warehouseId;
    private Id stockingLocationId;

    // Map to hold processed data
    private Map<Id, Id> supplierToPurchaseOrderIdMap = new Map<Id, Id>();

    public BulkPurchaseOrderBatch(String orderQuantitiesJson, String warehouseId, Id stockingLocationId) {
        this.orderQuantitiesJson = orderQuantitiesJson;
        this.warehouseId = warehouseId;
        this.stockingLocationId = stockingLocationId;
    }

    // Start Method
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Deserialize order quantities to create records
        List<OrderQuantityWrapper> orderQuantities = (List<OrderQuantityWrapper>)
            JSON.deserialize(orderQuantitiesJson, List<OrderQuantityWrapper>.class);

        Set<Id> productIds = new Set<Id>();
        for (OrderQuantityWrapper order : orderQuantities) {
            productIds.add(order.ProductId);
        }

        // Query Products with Supplier details for all relevant orders
        return Database.getQueryLocator([
            SELECT Id, Lodestone__Supplier__c 
            FROM Product2 
            WHERE Id IN :productIds
        ]);
    }

    // Execute Method
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Map<Id, Product2> productMap = new Map<Id, Product2>((List<Product2>)scope);

        // Deserialize JSON to access OrderQuantities
        List<OrderQuantityWrapper> orderQuantities = (List<OrderQuantityWrapper>)
            JSON.deserialize(orderQuantitiesJson, List<OrderQuantityWrapper>.class);

        // Step 1: Group OrderQuantities by Supplier
        Map<Id, List<OrderQuantityWrapper>> supplierToOrderQuantities = new Map<Id, List<OrderQuantityWrapper>>();
        for (OrderQuantityWrapper order : orderQuantities) {
            Product2 product = productMap.get(order.ProductId);
            if (product != null && product.Lodestone__Supplier__c != null) {
                if (!supplierToOrderQuantities.containsKey(product.Lodestone__Supplier__c)) {
                    supplierToOrderQuantities.put(product.Lodestone__Supplier__c, new List<OrderQuantityWrapper>());
                }
                supplierToOrderQuantities.get(product.Lodestone__Supplier__c).add(order);
            }
        }

        // Step 2: Create Purchase Orders
        List<Lodestone__Purchase_Order__c> purchaseOrders = new List<Lodestone__Purchase_Order__c>();
        String recTypeId = Schema.SObjectType.Lodestone__Purchase_Order__c.getRecordTypeInfosByName().get('Stock PO').getRecordTypeId();
        for (Id supplierId : supplierToOrderQuantities.keySet()) {
            Lodestone__Purchase_Order__c purchaseOrder = new Lodestone__Purchase_Order__c(
                Lodestone__Account__c = supplierId,
                IMagic__Status__c = 'Draft',
                Lodestone__PO_Date__c = Date.today(),
                RecordTypeId = recTypeId
            );
            purchaseOrders.add(purchaseOrder);
        }

        // Insert Purchase Orders
        insert purchaseOrders;

        // Map Purchase Order IDs back to Supplier IDs
        for (Lodestone__Purchase_Order__c po : purchaseOrders) {
            supplierToPurchaseOrderIdMap.put(po.Lodestone__Account__c, po.Id);
        }

        // Step 3: Create Purchase Order Line Items
        List<Lodestone__Purchase_Order_Line__c> purchaseOrderLineItems = new List<Lodestone__Purchase_Order_Line__c>();
        for (OrderQuantityWrapper order : orderQuantities) {
            Product2 product = productMap.get(order.ProductId);
            if (product != null && product.Lodestone__Supplier__c != null) {
                Id purchaseOrderId = supplierToPurchaseOrderIdMap.get(product.Lodestone__Supplier__c);
                if (purchaseOrderId != null) {
                    Lodestone__Purchase_Order_Line__c lineItem = new Lodestone__Purchase_Order_Line__c(
                        Lodestone__Product__c = order.ProductId,
                        Lodestone__Quantity__c = order.OrderQuantity,
                        Lodestone_Stocking_Location__c = stockingLocationId,
                        Lodestone__Purchase_Order__c = purchaseOrderId
                    );
                    purchaseOrderLineItems.add(lineItem);
                }
            }
        }

        // Insert Purchase Order Line Items
        insert purchaseOrderLineItems;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch process completed for Purchase Orders and Line Items.');
    }

    public class OrderQuantityWrapper {
        @AuraEnabled public String ProductId;
        @AuraEnabled public Integer OrderQuantity;
    
        public OrderQuantityWrapper() {}
    
        public OrderQuantityWrapper(String productId, Integer orderQuantity) {
            this.ProductId = productId;
            this.OrderQuantity = orderQuantity;
        }
    }
    
}