/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
public with sharing class OrderProductReservedLWC {
    @AuraEnabled(cacheable=true)
    public static List<String> getActiveRecordTypes(String objectName) {
        System.debug('objectName :: '+objectName);
        List<RecordType> recordTypes = [SELECT Name FROM RecordType WHERE SObjectType = :objectName AND IsActive = true];
        System.debug('recordTypes :: '+recordTypes);
        List<String> recordTypeNames = new List<String>();
        for (RecordType rt : recordTypes) {
            recordTypeNames.add(rt.Name);
        }
        return recordTypeNames;
    }
    

    @AuraEnabled
    public static List<OrderLineWrapper> getProducts(Id orderId){
        try {
            Set<Id> setOfProdIds = new Set<Id>();
            Set<Id> setOfStockLocIds = new Set<Id>();
            List<OrderLineWrapper> orderLineWrapperList = new List<OrderLineWrapper>();
            List<OrderItem> orderItemList = [SELECT Id, OrderId,IMagic__Stocking_Location__c,Product2Id,Quantity,Product2.RecordType.Name,Product2.Lodestone__Supplier__c,Product2.Lodestone__Supplier__r.Name,
                                            Product2.Name,IMagic__Stocking_Location__r.Name,IMagic__Reserved_Quantity__c,IMagic__PO_Quantity__c,IMagic__Remaining_QTY__c,UnitPrice
                                            FROM OrderItem WHERE OrderId =: orderId AND Quantity > 0 AND IMagic__Remaining_QTY__c > 0];

            for(OrderItem orditem : orderItemList){
                setOfProdIds.add(orditem.Product2Id);
                setOfStockLocIds.add(orditem.IMagic__Stocking_Location__c);
            }     

            Map<String,IMagic__Inventory__c> mapOfInventory = getRelatedInventory(setOfProdIds,setOfStockLocIds);
            System.debug('mapOfInventory :: '+mapOfInventory);
            for(OrderItem orditem : orderItemList){
                String key = orditem.Product2Id + '::' + orditem.IMagic__Stocking_Location__c;
                OrderLineWrapper wrap = new OrderLineWrapper();
                wrap.Id = orditem.Id;
                wrap.orderId = orditem.OrderId;
                wrap.stockingLocationId = orditem.IMagic__Stocking_Location__c;
                wrap.stockingLocationName = orditem.IMagic__Stocking_Location__r.Name;
                wrap.unitPrice = orditem.UnitPrice != null ? orditem.UnitPrice : 0;
                wrap.quantityOrdered = orditem.Quantity != null ? orditem.Quantity : 0;
                wrap.quantityReserved = orditem.IMagic__Reserved_Quantity__c != null ? orditem.IMagic__Reserved_Quantity__c : 0;
                wrap.quantityRemaining = orditem.IMagic__Remaining_QTY__c != null ? orditem.IMagic__Remaining_QTY__c : 0;
                wrap.quantityPO = orditem.IMagic__PO_Quantity__c != null ? orditem.IMagic__PO_Quantity__c : 0;
                wrap.newReservedQuantity = 0;
                wrap.productId = orditem.Product2Id;
                wrap.productName = orditem.Product2.Name;
                wrap.productRecordTypeName = orditem.Product2.RecordType.Name;
                wrap.isSerialControlProduct = orditem.Product2.RecordType.Name == 'Serial Control' ? true : false;
                if(!String.isBlank(orditem.Product2?.Lodestone__Supplier__c)){     
                    wrap.supplierId = orditem.Product2?.Lodestone__Supplier__c != null ? orditem.Product2.Lodestone__Supplier__c : null;
                    wrap.supplierName = orditem.Product2?.Lodestone__Supplier__c != null ? orditem.Product2.Lodestone__Supplier__r.Name : null;
                }
                wrap.inventoryId = mapOfInventory.get(key) != null ? mapOfInventory.get(key).Id : null;               
                wrap.inventoryAvailableQuantity = mapOfInventory.get(key) != null ? mapOfInventory.get(key).IMagic__Quantity_on_Hand__c : 0;
                wrap.isSelected = false;
                wrap.createPO = false;
                wrap.selectedType = '';
                orderLineWrapperList.add(wrap);
            }
            System.debug('orderLineWrapperList :: '+orderLineWrapperList);
            return orderLineWrapperList;
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Map<String,IMagic__Inventory__c> getRelatedInventory(Set<Id> proIds,Set<Id> stockingLocationIds){
        System.debug('proIds :: '+proIds);
        System.debug('stockingLocationIds :: '+stockingLocationIds);
        Map<String, IMagic__Inventory__c> MapOfInv = new Map<String, IMagic__Inventory__c>();
        List<IMagic__Inventory__c> inventoryList = [SELECT Id,IMagic__Product__c,IMagic__Stocking_Location__c,IMagic__Quantity_Reserved__c,IMagic__Quantity_on_Hand__c,
                                            IMagic__Product__r.RecordType.Name,IMagic__Cost__c FROM IMagic__Inventory__c 
                                            WHERE IMagic__Product__c IN: proIds AND IMagic__Stocking_Location__c IN: stockingLocationIds];
        for(IMagic__Inventory__c inv : inventoryList){
            String key = inv.IMagic__Product__c + '::' + inv.IMagic__Stocking_Location__c;
            MapOfInv.put(key, inv);
        }
        return MapOfInv;
    }

    public static IMagic__Inventory__c initializeInventory(String key,Map<String,IMagic__Inventory__c> MapofInv){
        try {
            IMagic__Inventory__c inventory = new IMagic__Inventory__c();
            inventory.Id = MapofInv.get(key).Id;
            inventory.IMagic__Quantity_on_Hand__c = MapofInv.get(key).IMagic__Quantity_on_Hand__c != null ? MapofInv.get(key).IMagic__Quantity_on_Hand__c : 0;
            inventory.IMagic__Cost__c = MapofInv.get(key).IMagic__Cost__c != null ? MapofInv.get(key).IMagic__Cost__c : 0;
            inventory.IMagic__Quantity_Reserved__c = MapofInv.get(key).IMagic__Quantity_Reserved__c != null ? MapofInv.get(key).IMagic__Quantity_Reserved__c : 0;    
            return inventory; 
        } catch (Exception e) {
            System.debug('e.getMessage() :: '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }                                                       
    }


    @AuraEnabled
    public static String reservedOrderProduct(String OrderLineJSON){
        String orderId = '';
        try {
            Set<Id> setOfProdIds = new Set<Id>();
            Set<Id> setOfStockLocIds = new Set<Id>();
            List<OrderItem> orderItemList_Updated = new List<OrderItem>();
            List<IMagic__Inventory__c> inventoryList_Updated = new List<IMagic__Inventory__c>();
            List<IMagic__Inventory_Detail__c> inventoryDetailList_Updated = new List<IMagic__Inventory_Detail__c>();
            List<OrderLineWrapper> OrderLineWrap = (List<OrderLineWrapper>) JSON.deserialize(OrderLineJSON, List<OrderLineWrapper>.class);
            List<OrderLineWrapper> OrderLineWrapperList_PO = new List<OrderLineWrapper>();
            Map<Id,IMagic__Transaction_History__c> invTransactionMap = new Map<Id,IMagic__Transaction_History__c>();
            
            
            for(OrderLineWrapper line : OrderLineWrap){
                setOfProdIds.add(line.productId);
                setOfStockLocIds.add(line.stockingLocationId);
                orderId = line.orderId;
            }
            Map<String,IMagic__Inventory__c> mapOfInventory = getRelatedInventory(setOfProdIds,setOfStockLocIds);
            for(OrderLineWrapper line : OrderLineWrap){
                String key = line.productId + '::' + line.stockingLocationId;
                IMagic__Transaction_History__c invTransaction = new IMagic__Transaction_History__c();
                IMagic__Inventory__c inventory =  initializeInventory(key,mapOfInventory);
                Decimal orderItem_reservedQty = line.quantityReserved;
                Decimal orderItem_PO_Qty = line.quantityPO;

                invTransaction.IMagic__Type__c = 'Order Reserved';
                invTransaction.IMagic__Transaction_Date_Time__c = Datetime.now();
                invTransaction.IMagic__Source_Stocking_Location__c = line.stockingLocationId;
                invTransaction.IMagic__Inventory__c = line.inventoryId;
                invTransaction.IMagic__Product__c = line.productId;
                invTransaction.IMagic__Order_Product__c = line.Id;
                invTransaction.IMagic__Old_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
                invTransaction.IMagic__Old_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                invTransaction.IMagic__Old_Reserved_Quantity__c = orderItem_reservedQty;
                invTransaction.IMagic__Quantity__c = line.newReservedQuantity;
                invTransaction.IMagic__Old_PO_Quantity__c	 = orderItem_PO_Qty;


                if(line.newReservedQuantity <= inventory.IMagic__Quantity_on_Hand__c){
                    orderItem_reservedQty += line.newReservedQuantity;
                    inventory.IMagic__Quantity_Reserved__c += line.newReservedQuantity;
                    inventory.IMagic__Quantity_on_Hand__c -= line.newReservedQuantity;
                    
                    invTransaction.IMagic__New_Inventory_Quantity_Reserved__c	 = inventory.IMagic__Quantity_Reserved__c;
                    invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                    invTransaction.IMagic__New_Reserved_Quantity__c = orderItem_reservedQty;
                }
                else{
                    Decimal new_PO_Qty = line.newReservedQuantity - inventory.IMagic__Quantity_on_Hand__c;
                    orderItem_reservedQty += inventory.IMagic__Quantity_on_Hand__c;
                    inventory.IMagic__Quantity_Reserved__c += inventory.IMagic__Quantity_on_Hand__c;
                    inventory.IMagic__Quantity_on_Hand__c = 0;
                    orderItem_PO_Qty += new_PO_Qty;

                    invTransaction.IMagic__New_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
                    invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                    invTransaction.IMagic__New_PO_Quantity__c = new_PO_Qty;
                    invTransaction.IMagic__New_Reserved_Quantity__c = orderItem_reservedQty;
                }
                invTransactionMap.put(line.Id,invTransaction);
                mapOfInventory.put(key,inventory);
                
                OrderItem oi = new OrderItem();
                oi.Id = line.Id;
                oi.IMagic__Reserved_Quantity__c = orderItem_reservedQty;
                oi.IMagic__PO_Quantity__c = orderItem_PO_Qty;
                oi.IMagic__Create_PO__c = line.createPO;
                orderItemList_Updated.add(oi);

                if(line.isSerialControlProduct){
                    for(serialListWrapper serial : line.serialList){
                        IMagic__Inventory_Detail__c detail = new IMagic__Inventory_Detail__c();
                        detail.Id = serial.invDetailId;
                        detail.IMagic__Quantity_on_order__c = 1;
                        detail.IMagic__Quantity__c = 0;
                        detail.IMagic__Order_Product__c = line.Id;
                        inventoryDetailList_Updated.add(detail);
                    }
                }
                if(line.createPO){
                   OrderLineWrapperList_PO.add(line);
                }
            }

            System.debug('orderItemList_Updated :: '+orderItemList_Updated);
            if(!orderItemList_Updated.isEmpty()){
                update orderItemList_Updated;
                System.debug('orderItemList_Updated updated');
            }
            if(mapOfInventory != null){
                inventoryList_Updated = mapOfInventory.values();
            }
            System.debug('invListtoUpdate :: '+inventoryList_Updated);
            if(!inventoryList_Updated.isEmpty()){
                update inventoryList_Updated;
                System.debug('invListtoUpdate updated');
            }

            
            System.debug('creating PO :: '+OrderLineWrapperList_PO);
            List<Lodestone__Purchase_Order_Line__c> insertedPOLines = new List<Lodestone__Purchase_Order_Line__c>();
            if(!OrderLineWrapperList_PO.isEmpty()){
                insertedPOLines = createPO(OrderLineWrapperList_PO);
            }
            System.debug('created PO');


            if(!insertedPOLines.isEmpty()){
                for(Lodestone__Purchase_Order_Line__c poLine : insertedPOLines){
                    IMagic__Transaction_History__c invTransaction = invTransactionMap.get(poLine.Lodestone__Purchase_Order__c);
                    if(invTransaction != null){
                        invTransaction.IMagic__Purchase_OrderLine_Item__c = poLine.Id;
                    }

                }
            }

            System.debug('creating invTransactionMap :: '+invTransactionMap);
            if(invTransactionMap != null){
                insert invTransactionMap.values();
                System.debug('invTransactionMap inserted');
            }


            System.debug('creating inventoryDetailList_Updated :: '+inventoryDetailList_Updated);
            if(!inventoryDetailList_Updated.isEmpty()){
                for(IMagic__Inventory_Detail__c detail : inventoryDetailList_Updated){
                    if(invTransactionMap != null){
                        detail.IMagic__Inventory_Transaction__c = invTransactionMap.get(detail.IMagic__Order_Product__c).Id;
                        
                    }
                }
                update inventoryDetailList_Updated;
                System.debug('inventoryDetailList_Updated update');
            }

            return orderId;
        } 
        catch (AuraHandledException e) {
            System.debug('test '+e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('reservedOrderProduct :: ' + e.getMessage());
            throw new AuraHandledException('Custom Exception: ' + e.getMessage());
        }
    }

    public static List<Lodestone__Purchase_Order_Line__c> createPO(List<OrderLineWrapper> OrderLineWrapperList){
        Map<String,List<OrderLineWrapper>> mapOfOrderLineWrapper = new Map<String,List<OrderLineWrapper>>();
        Map<String,Lodestone__Purchase_Order__c> mapOfString_PO = new Map<String,Lodestone__Purchase_Order__c>();
        List<Lodestone__Purchase_Order_Line__c> PO_LineList = new List<Lodestone__Purchase_Order_Line__c>();
        List<OrderItem> orderItemList_Updated = new List<OrderItem>();
        for(OrderLineWrapper line : OrderLineWrapperList){
            System.debug('productName :: '+line.productName);
            if(line.supplierId == null){
                System.debug('Supplier Missing for Product :: '+ line.productName);
                throw new AuraHandledException('Supplier Missing for Product :: '+ line.productName);
            }
            System.debug('Supplier Id :: '+line.supplierId);
            String key = line.supplierId + '::' + line.orderId + '::' + line.selectedType;
            List<OrderLineWrapper> tempList = new List<OrderLineWrapper>();
            if(mapOfOrderLineWrapper.containsKey(key)){
                tempList = mapOfOrderLineWrapper.get(key);
            }
            tempList.add(line);
            mapOfOrderLineWrapper.put(key,tempList);
        }
        System.debug('creating mapOfOrderLineWrapper :: '+mapOfOrderLineWrapper);
        for(String key : mapOfOrderLineWrapper.keySet()){
            String[] parts = key.split('::');
            String supplierId = parts[0];
            String orderId = parts[1];
            String selectedType = parts[2];

            System.debug('Supplier Id: ' + supplierId);
            System.debug('Order Id: ' + orderId);
            System.debug('Selected Type: ' + selectedType);

            String recTypeId = Schema.SObjectType.Lodestone__Purchase_Order__c.getRecordTypeInfosByName().get(selectedType).getRecordTypeId();
            System.debug('recTypeId: ' + recTypeId);
            Lodestone__Purchase_Order__c PO = new Lodestone__Purchase_Order__c();
            PO.Lodestone__Account__c = supplierId;
            PO.Lodestone__Order__c = orderId;
            PO.Lodestone__PO_Date__c = Date.today();
            PO.RecordTypeId = recTypeId;

            System.debug('PO : ' + PO);
            mapOfString_PO.put(key,PO);
        }
        System.debug('mapOfString_PO : ' + mapOfString_PO.values().size());
        if(!mapOfString_PO.isEmpty()){
            insert mapOfString_PO.values();
        }
        System.debug('mapOfString_PO inserted : ' + mapOfString_PO);
        
        for(OrderLineWrapper line : OrderLineWrapperList){
            String key = line.supplierId + '::' + line.orderId + '::' + line.selectedType;
            Lodestone__Purchase_Order_Line__c PO_Line = new Lodestone__Purchase_Order_Line__c();
            PO_Line.Lodestone__Product__c = line.productId;
            PO_Line.Lodestone__Quantity__c = (line.newReservedQuantity - line.inventoryAvailableQuantity);
            PO_Line.Lodestone__Cost_Price__c = line.unitPrice;
            PO_Line.Lodestone__Order_Product__c = line.Id;
            PO_Line.Lodestone_Stocking_Location__c = line.stockingLocationId;
            PO_Line.Lodestone__Purchase_Order__c = mapOfString_PO.get(key).Id;
            PO_LineList.add(PO_Line);

            OrderItem oi = new OrderItem();
            oi.Id = line.Id;
            oi.IMagic__PO_Created__c = true;
            orderItemList_Updated.add(oi);
        }
        System.debug('PO_LineList size  : ' + PO_LineList.size());
        if(!PO_LineList.isEmpty()){
            insert PO_LineList;
        }
        System.debug('PO_LineList inserted : ' + PO_LineList);

        if(!orderItemList_Updated.isEmpty()){
            update orderItemList_Updated;
        }
        System.debug('orderItemList_Updated inserted : ' + orderItemList_Updated);
        return PO_LineList;
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
        @AuraEnabled public Decimal quantityPO {get; set;}
        @AuraEnabled public Decimal newReservedQuantity {get; set;}
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
        @AuraEnabled public String selectedType {get; set;}
        @AuraEnabled public Boolean createPO {get; set;}
    }

    public class serialListWrapper {
        @AuraEnabled public String invDetailId { get; set; }
        @AuraEnabled public String invDetailName { get; set; }
    }
}