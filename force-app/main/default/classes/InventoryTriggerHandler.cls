public with sharing class InventoryTriggerHandler {
    public static void handleInventory_Insert_Update(Set<Id> productIds){
        try {
            List<IMagic__Inventory__c> invList = [SELECT Id,IMagic__Quantity_on_Hand__c,IMagic__Quantity_Reserved__c,IMagic__Cost__c,IMagic__Stocking_Location__c,IMagic__Product__c,Product__r.IMagic__Profit_Margin__c
                                         FROM IMagic__Inventory__c WHERE IMagic__Product__c IN: productIds AND (IMagic__Quantity_on_Hand__c > 0 OR IMagic__Quantity_Reserved__c > 0)];
        
        Map<Id, Decimal> productToQuantityOnHandMap = new Map<Id, Decimal>();
        Map<Id, Decimal> productToQuantityReservedMap = new Map<Id, Decimal>();
        Map<Id, Decimal> productToCostMap = new Map<Id, Decimal>();
        Map<Id, Decimal> productToMarginMap = new Map<Id, Decimal>();
        System.debug('here 1');
        
        for (IMagic__Inventory__c inventory : invList) {
            productToMarginMap.put(inventory.IMagic__Product__c, inventory.IMagic__Product__r.IMagic__Profit_Margin__c);
            
            if (productToQuantityOnHandMap.containsKey(inventory.IMagic__Product__c)) {
                productToQuantityOnHandMap.put(inventory.IMagic__Product__c, 
                    productToQuantityOnHandMap.get(inventory.IMagic__Product__c) + inventory.IMagic__Quantity_on_Hand__c);
            } else {
                productToQuantityOnHandMap.put(inventory.IMagic__Product__c, inventory.IMagic__Quantity_on_Hand__c);
            }
            
        System.debug('here 2');
            if (productToQuantityReservedMap.containsKey(inventory.IMagic__Product__c)) {
                productToQuantityReservedMap.put(inventory.IMagic__Product__c, 
                    productToQuantityReservedMap.get(inventory.IMagic__Product__c) + inventory.IMagic__Quantity_Reserved__c);
            } else {
                productToQuantityReservedMap.put(inventory.IMagic__Product__c, inventory.IMagic__Quantity_Reserved__c);
            }
            System.debug('here 3');

            Decimal totalCost = inventory.IMagic__Cost__c * inventory.IMagic__Quantity_on_Hand__c;
            if (productToCostMap.containsKey(inventory.Product__c)) {
                productToCostMap.put(inventory.IMagic__Product__c, productToCostMap.get(inventory.IMagic__Product__c) + totalCost);
            } else {
                productToCostMap.put(inventory.IMagic__Product__c, totalCost);
            }
            System.debug('here 4');
        }

        List<Product2> productsToUpdate = new List<Product2>();
        for (Id productId : productIds) {
            System.debug('here 5');
            Product2 product = new Product2();
            Decimal quantityOnHand = productToQuantityOnHandMap.get(productId) != null ? productToQuantityOnHandMap.get(productId) : 0;
            Decimal productCost = productToCostMap.get(productId) != null && quantityOnHand != 0 ? (productToCostMap.get(productId) / quantityOnHand) : 0;
            Decimal productMargin = productToMarginMap.get(productId) != null ? productToMarginMap.get(productId) : 0;
            Decimal marginPercentage = productMargin / 100;
            // Calculate sales price
            Decimal salesPrice = productCost * (1 + marginPercentage);

            System.debug('here 6');
            product.Id = productId;
            product.Lodestone__Quantity_On_Hand__c = quantityOnHand;
            product.IMagic__Quantity_Reserved__c = productToQuantityReservedMap.get(productId) != null ? productToQuantityReservedMap.get(productId) : 0;
            product.Lodestone__Cost_Price__c = productCost;
            product.Lodestone__Sale_Price__c = salesPrice;

            System.debug('here 7');
            productsToUpdate.add(product);
        }
        System.debug('productsToUpdate :: '+productsToUpdate);
        if (!productsToUpdate.isEmpty()) {
            update productsToUpdate;
        }
        } catch (Exception ex) {
            throw new AuraHandledException('InventoryTriggerHandler :: ' + ex.getMessage());
        }
    }
}