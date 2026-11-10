public with sharing class orderProductUnReserved {
    @AuraEnabled
    public static List<OrderLineWrapper> getProducts(Id orderId){
        try {
            Set<Id> setOfProdIds = new Set<Id>();
            Set<Id> setOfStockLocIds = new Set<Id>();
            List<OrderLineWrapper> orderLineWrapperList = new List<OrderLineWrapper>();
            List<OrderItem> orderItemList = [
                SELECT Id, OrderId, IMagic__Stocking_Location__c, Product2Id, Quantity, Product2.RecordType.Name, Product2.Lodestone__Supplier__c,Product2.Lodestone__Supplier__r.Name,
                Product2.Name, IMagic__Stocking_Location__r.Name, IMagic__Reserved_Quantity__c, IMagic__PO_Quantity__c, IMagic__Remaining_QTY__c,IMagic__Backordered_Qty__c, UnitPrice,
                Product2.RecordType.DeveloperName
                FROM OrderItem WHERE OrderId =: orderId AND Quantity > 0 AND IMagic__Reserved_Quantity__c > 0 AND Order.Status != 'Invoiced'
            ];

            for(OrderItem orditem : orderItemList){
                setOfProdIds.add(orditem.Product2Id);
                setOfStockLocIds.add(orditem.IMagic__Stocking_Location__c);
            }     

            Map<String,IMagic__Inventory__c> mapOfInventory = getRelatedInventory(setOfProdIds,setOfStockLocIds);

            for(OrderItem orditem : orderItemList){
                String key = orditem.Product2Id + '::' + orditem.IMagic__Stocking_Location__c;
                string supplierId = orditem.Product2.Lodestone__Supplier__c;
                string inventoryId = mapOfInventory.get(key)?.Id;
                
                supplierId = supplierId ?? '';
                inventoryId = inventoryId ?? '';
                
                OrderLineWrapper wrap = new OrderLineWrapper();
                wrap.Id = orditem.Id;
                wrap.orderId = orditem.OrderId;
                wrap.stockingLocationId = orditem.IMagic__Stocking_Location__c;
                wrap.stockingLocationName = orditem.IMagic__Stocking_Location__r.Name;
                wrap.unitPrice = orditem.UnitPrice != null ? orditem.UnitPrice : 0;
                wrap.quantityOrdered = orditem.Quantity != null ? orditem.Quantity : 0;
                wrap.quantityReserved = orditem.IMagic__Reserved_Quantity__c != null ? orditem.IMagic__Reserved_Quantity__c : 0;
                wrap.quantityRemaining = orditem.IMagic__Remaining_QTY__c != null ? orditem.IMagic__Remaining_QTY__c : 0;
                wrap.newUnReservedQuantity = 0;
                wrap.productId = orditem.Product2Id;
                wrap.productName = orditem.Product2.Name;
                wrap.productRecordTypeName = orditem.Product2.RecordType.DeveloperName;
                wrap.isSerialControlProduct = orditem.Product2.RecordType.DeveloperName == 'Serial_Control';
                wrap.supplierId = supplierId;
                wrap.supplierName = orditem.Product2?.Lodestone__Supplier__c != null ? orditem.Product2.Lodestone__Supplier__r.Name : null;
                wrap.inventoryId = inventoryId;
                wrap.inventoryAvailableQuantity = mapOfInventory.get(key) != null ? mapOfInventory.get(key).IMagic__Quantity_on_Hand__c : 0;
                wrap.isSelected = false;
                orderLineWrapperList.add(wrap);
            }
            System.debug('orderLineWrapperList :: '+orderLineWrapperList);
            return orderLineWrapperList;
        } catch (Exception ex) {
            string message = '' +
            '\nMessage: ' + ex.getMessage() +
            '\nLineNumber: ' + ex.getLineNumber() +
            '\nStackTrace: ' + ex.getStackTraceString() +
            '\nExceptionType: ' + ex.getTypeName();

            System.debug('Error: ' + message);
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public static Map<String,IMagic__Inventory__c> getRelatedInventory(Set<Id> proIds,Set<Id> stockingLocationIds){
        System.debug('proIds :: '+proIds);
        System.debug('stockingLocationIds :: '+stockingLocationIds);
        Map<String, IMagic__Inventory__c> MapOfInv = new Map<String, IMagic__Inventory__c>();
        List<IMagic__Inventory__c> inventoryList = [SELECT Id,IMagic__Product__c,IMagic__Stocking_Location__c,IMagic__Quantity_Reserved__c,IMagic__Quantity_on_Hand__c,
                                            IMagic__Product__r.RecordType.DeveloperName FROM IMagic__Inventory__c 
                                            WHERE IMagic__Product__c IN: proIds AND IMagic__Stocking_Location__c IN: stockingLocationIds];
        for(IMagic__Inventory__c inv : inventoryList){
            String key = inv.IMagic__Product__c + '::' + inv.IMagic__Stocking_Location__c;
            MapOfInv.put(key, inv);
        }
        return MapOfInv;
    }

    @AuraEnabled
    public static String unReservedOrderProduct(String OrderLineJSON){
        String orderId = '';
        try {
            Set<Id> setOfProdIds = new Set<Id>();
            Set<Id> setOfStockLocIds = new Set<Id>();
            List<OrderItem> orderItemList_Updated = new List<OrderItem>();
            List<IMagic__Inventory__c> inventoryList_Updated = new List<IMagic__Inventory__c>();
            List<IMagic__Inventory_Detail__c> inventoryDetailList_Updated = new List<IMagic__Inventory_Detail__c>();
            List<OrderLineWrapper> OrderLineWrap = (List<OrderLineWrapper>) JSON.deserialize(OrderLineJSON, List<OrderLineWrapper>.class);
            
            
            for(OrderLineWrapper line : OrderLineWrap){
                setOfProdIds.add(line.productId);
                setOfStockLocIds.add(line.stockingLocationId);
                orderId = line.orderId;
            }
            Map<String,IMagic__Inventory__c> mapOfInventory = getRelatedInventory(setOfProdIds,setOfStockLocIds);
            for(OrderLineWrapper line : OrderLineWrap){
                String key = line.productId + '::' + line.stockingLocationId;
                IMagic__Inventory__c inventory =  mapOfInventory.get(key);
                Decimal orderItem_reservedQty = line.quantityReserved;

                orderItem_reservedQty -= line.newUnReservedQuantity;
                inventory.IMagic__Quantity_Reserved__c -= line.newUnReservedQuantity;
                inventory.IMagic__Quantity_on_Hand__c += line.newUnReservedQuantity;
                System.debug('inventory after :: '+inventory);
                mapOfInventory.put(key,inventory);

                OrderItem oi = new OrderItem();
                oi.Id = line.Id;
                oi.IMagic__Reserved_Quantity__c = orderItem_reservedQty;
                orderItemList_Updated.add(oi);


                if(line.isSerialControlProduct){
                    for(serialListWrapper serial : line.serialList){
                        IMagic__Inventory_Detail__c detail = new IMagic__Inventory_Detail__c();
                        detail.Id = serial.invDetailId;
                        detail.IMagic__Quantity_on_order__c = 0;
                        detail.IMagic__Quantity__c = 1;
                        detail.IMagic__Order_Product__c = line.Id;
                        System.debug('detail :: '+detail);
                        inventoryDetailList_Updated.add(detail);
                    }
                }
            }
            if(!orderItemList_Updated.isEmpty()){
                update orderItemList_Updated;
            }
            if(mapOfInventory != null){
                inventoryList_Updated = mapOfInventory.values();
            }
            if(!inventoryList_Updated.isEmpty()){
                update inventoryList_Updated;
            }

            if(!inventoryDetailList_Updated.isEmpty()){
                update inventoryDetailList_Updated;
            }
            return orderId;
        }
        catch (AuraHandledException e) {
            throw e;
        } catch (Exception ex) {
            string message = '' +
            '\nMessage: ' + ex.getMessage() +
            '\nLineNumber: ' + ex.getLineNumber() +
            '\nStackTrace: ' + ex.getStackTraceString() +
            '\nExceptionType: ' + ex.getTypeName();

            System.debug('reservedOrderProduct :: ' + message);
            System.debug('reservedOrderProduct :: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }


    public class OrderLineWrapper{
        @AuraEnabled public String Id {get; set;}
        @AuraEnabled public String orderId {get; set;}
        @AuraEnabled public String stockingLocationId {get; set;}
        @AuraEnabled public String stockingLocationName {get; set;}
        @AuraEnabled public Decimal unitPrice {get; set;}
        @AuraEnabled public Decimal quantityOrdered {get; set;}
        @AuraEnabled public Decimal quantityReserved {get; set;}
        @AuraEnabled public Decimal quantityRemaining {get; set;}
        @AuraEnabled public Decimal newUnReservedQuantity {get; set;}
        @AuraEnabled public String productId {get; set;}
        @AuraEnabled public String productName {get; set;}
        @AuraEnabled public String productRecordTypeName {get; set;}
        @AuraEnabled public Boolean isSerialControlProduct {get; set;}
        @AuraEnabled public String supplierId {get; set;}
        @AuraEnabled public String supplierName {get; set;}
        @AuraEnabled public String inventoryId {get; set;}
        @AuraEnabled public Decimal inventoryAvailableQuantity {get; set;}
        @AuraEnabled public List<serialListWrapper> serialList {get; set;}
        @AuraEnabled public Boolean isSelected {get; set;}
    }

    public class serialListWrapper {
        @AuraEnabled public String invDetailId { get; set; }
        @AuraEnabled public String invDetailName { get; set; }
    }
}