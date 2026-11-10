public with sharing class POLineTriggerHandler {
    public static void handlePOLine_Insert_Update(Set<Id> productIds){
        List<Lodestone__Purchase_Order_Line__c> POLineList = [SELECT Id,Lodestone__Quantity__c,Received_Quantity__c,Inventory__c,Lodestone__Product__c,Lodestone_Stocking_Location__c 
                                                       FROM Lodestone__Purchase_Order_Line__c WHERE Lodestone__Product__c IN: productIds AND 
                                                       Lodestone__Quantity__c > 0];
        
        Map<Id, Decimal> productToPOQtyMap = new Map<Id, Decimal>();
        for (Lodestone__Purchase_Order_Line__c poLine : POLineList) {
            Decimal Qty = poLine.Lodestone__Quantity__c != null ?  poLine.Lodestone__Quantity__c : 0;
            Decimal RecievedQty = poLine.IMagic__Received_Quantity__c != null ?  poLine.IMagic__Received_Quantity__c : 0;
            Decimal newPOQty = Qty - RecievedQty;
            System.debug('newPOQty :: '+newPOQty);
            if (productToPOQtyMap.containsKey(poLine.Lodestone__Product__c)) {
                productToPOQtyMap.put(poLine.Lodestone__Product__c, productToPOQtyMap.get(poLine.Lodestone__Product__c) + newPOQty);
            } else {
                productToPOQtyMap.put(poLine.Lodestone__Product__c, newPOQty);
            }
        }

        List<Product2> productsToUpdate = new List<Product2>();
        for (Id productId : productToPOQtyMap.keySet()) {
            System.debug('productToPOQtyMap.get(productId) :: '+productToPOQtyMap.get(productId));
            Product2 product = new Product2();
            product.Id = productId;
            product.IMagic__PO_Quantity__c = productToPOQtyMap.get(productId);
            productsToUpdate.add(product);
        }
        System.debug('productsToUpdate POLine :: '+productsToUpdate);
        // Perform the update on Product records
        if (!productsToUpdate.isEmpty()) {
            update productsToUpdate;
            System.debug('productsToUpdate Updated');
        }
    }
}