public with sharing class createBulkPOController {
    @AuraEnabled
    public static List<Product2> getProductList(String recordId,Date startDate,Date endDate) {
        try { 
            System.debug('endDate :: '+endDate);
            System.debug('startDate :: '+startDate);
            // Query to get products for the specified warehouse
            List<Product2> products = [
                SELECT Id, Name, Lodestone__Quantity_On_Hand__c, IMagic__Quantity_Reserved__c, IMagic__PO_Quantity__c, Lodestone__Supplier__c,
                       IMagic__Warehouse__c, IMagic__Warehouse__r.Name, IMagic__Reorder_Level__c, IMagic__Reorder_Quantity__c
                FROM Product2
                WHERE IMagic__Warehouse__c = :recordId
                AND CreatedDate >= :startDate
                AND CreatedDate <= :endDate
            ];

            // Filter records in Apex where Reorder_Quantity__c is greater than or equal to Lodestone__Quantity_On_Hand__c
            List<Product2> filteredProducts = new List<Product2>();
            for (Product2 product : products) {
                if (product.IMagic__Reorder_Quantity__c >= product.Lodestone__Quantity_On_Hand__c) {
                    filteredProducts.add(product);
                }
            }
            return filteredProducts;
        } catch (Exception e) {
            // Handle any exceptions
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createBulkPurchaseOrders(String orderQuantitiesJson, String warehouseId) {
        try {
            if (String.isBlank(orderQuantitiesJson) || String.isBlank(warehouseId)) {
                throw new AuraHandledException('Invalid input: orderQuantitiesJson and warehouseId are required.');
            }

            Id stockingLocationId;
            List<IMagic__Stocking_Location__c> stockingLocations = [
                SELECT Id
                FROM IMagic__Stocking_Location__c
                WHERE IMagic__Warehouse__c = :warehouseId
                AND IMagic__is_Main_Stocking_Location__c = true
                LIMIT 1
            ];
            if (stockingLocations.isEmpty()) {
                throw new AuraHandledException('No main stocking location found for the specified warehouse.');
            }
            stockingLocationId = stockingLocations[0].Id;

            BulkPurchaseOrderBatch batch = new BulkPurchaseOrderBatch(orderQuantitiesJson, warehouseId, stockingLocationId);
            Database.executeBatch(batch, 20);

        } catch (Exception e) {
            throw new AuraHandledException('Error in createBulkPurchaseOrders: ' + e.getMessage());
        }
    }
    
}