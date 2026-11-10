public with sharing class StockAdjustmentController {


    @AuraEnabled(cacheable=true)
    public static IMagic__Stocking_Location__c getMainWarehouseStockingLocation() {
        // Query the main warehouse stocking location
        try {
            IMagic__Stocking_Location__c mainWarehouseStock = [
            SELECT Id, Name, IMagic__Warehouse__c, IMagic__Warehouse__r.Name 
            FROM IMagic__Stocking_Location__c 
            WHERE is_Main_Stocking_Location__c = true 
            LIMIT 1
        ];

        return mainWarehouseStock;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get getMainWarehouseStockingLocation :: ' + ex.getMessage());
        }
    }

    public static Map<String,IMagic__Inventory__c> getInventoryRecords(Set<Id> invIds) {
        try {
            List<IMagic__Inventory__c> inventoryRecords = [SELECT Id,Name, IMagic__Quantity_on_Hand__c,IMagic__Quantity_Reserved__c,IMagic__Cost__c FROM IMagic__Inventory__c WHERE Id IN: invIds];
            Map<String,IMagic__Inventory__c> inventoryMap = new Map<String,IMagic__Inventory__c>();
            for(IMagic__Inventory__c inv : inventoryRecords){
                inventoryMap.put(inv.Id,inv);
            }   
            return inventoryMap;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get related Inventory Record :: '+ex.getMessage());
        }
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
    public static Id createStockAdjustment_Line(String wareHouseId,String stockingLocationId,String transferJson){
        try {
            Set<Id> invIds = new Set<Id>();
            Map<String,IMagic__Inventory__c> InventoryMap = new Map<String,IMagic__Inventory__c>();
            List<stockAdjustmentLineWrapper> stockAdjustmentLineWrapperList = (List<stockAdjustmentLineWrapper>) JSON.deserialize(transferJson, List<stockAdjustmentLineWrapper>.class); 
            List<IMagic__Stock_Adjustment_Line__c> adjustmentLineList = new List<IMagic__Stock_Adjustment_Line__c>();
            List<IMagic__Transaction_History__c> transactionHistoryList = new List<IMagic__Transaction_History__c>();
            List<IMagic__Inventory__c> inventoryList_Update = new List<IMagic__Inventory__c>();
            List<IMagic__Inventory_Detail__c> inventoryDetailList_Insert = new List<IMagic__Inventory_Detail__c>();
            List<IMagic__Inventory_Detail__c> inventoryDetailList_Update = new List<IMagic__Inventory_Detail__c>();

            IMagic__Stock_Adjustment__c adjustment = insertStockAdjustment(wareHouseId,stockingLocationId);
            
            for(stockAdjustmentLineWrapper wrap : stockAdjustmentLineWrapperList){
                invIds.add(wrap.inventoryId);
            }

            if(!invIds.isEmpty()){
                InventoryMap = getInventoryRecords(invIds);  
            }

            for(stockAdjustmentLineWrapper wrap : stockAdjustmentLineWrapperList){
                adjustmentLineList.add(createStockAdjustmentLine(wrap,adjustment));
                transactionHistoryList.add(createInventoryTransaction(wrap,adjustment));
                IMagic__Inventory__c inventory = initializeInventory(wrap.inventoryId,InventoryMap);
                inventoryList_Update.add(createInventory(wrap,inventory));


                if(wrap.isSerialControlProduct){
                    for(serialNumberWrapper numberWrap : wrap.serialNumberList){
                        IMagic__Inventory_Detail__c inventoryDetail = new IMagic__Inventory_Detail__c();
                        inventoryDetail.IMagic__Inventory__c = wrap.inventoryId;
                        inventoryDetail.Name = numberWrap.serialNumber;
                        inventoryDetail.IMagic__Serial_Number__c = numberWrap.serialNumber;
                        inventoryDetail.IMagic__Quantity__c = 1;    
                        inventoryDetailList_Insert.add(inventoryDetail);   
                    }

                    for(serialListWrapper serialWrap : wrap.serialList){
                        IMagic__Inventory_Detail__c inventoryDetail = new IMagic__Inventory_Detail__c();
                        inventoryDetail.Id = serialWrap.invDetailId;
                        inventoryDetail.IMagic__Quantity__c = 0;    
                        inventoryDetailList_Update.add(inventoryDetail);   
                    }
                }
            }

            if(!adjustmentLineList.isEmpty()){
                insert adjustmentLineList;
            }

            if(!transactionHistoryList.isEmpty()){
                insert transactionHistoryList;
            }

            if(!inventoryList_Update.isEmpty()){
                update inventoryList_Update;
            }

            if(!inventoryDetailList_Insert.isEmpty()){
                insert inventoryDetailList_Insert;
            }

            if(!inventoryDetailList_Update.isEmpty()){
                update inventoryDetailList_Update;
            }

            return adjustment.Id;
        } catch (Exception e) {
            System.debug('e.getMessage() createStockAdjustment_Line :: '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static IMagic__Stock_Adjustment__c insertStockAdjustment(String wareHouseId,String stockingLocationId){
        try {
            IMagic__Stock_Adjustment__c adjustment = new IMagic__Stock_Adjustment__c();
            adjustment.IMagic__Warehouse__c = wareHouseId;
            adjustment.IMagic__Stocking_Location__c = stockingLocationId;
            adjustment.IMagic__Adjustment_Date__c = Date.today();
            insert adjustment;
            return adjustment;
        } catch (Exception e) {
            System.debug('e.getMessage() createStockAdjustment :: '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static IMagic__Stock_Adjustment_Line__c createStockAdjustmentLine(stockAdjustmentLineWrapper wrap,IMagic__Stock_Adjustment__c adjustment){
        IMagic__Stock_Adjustment_Line__c adjustmentLine = new IMagic__Stock_Adjustment_Line__c();
        adjustmentLine.IMagic__Action__c = wrap.action;
        adjustmentLine.IMagic__AdjustmentReason__c = wrap.adjustmentReason;
        adjustmentLine.IMagic__AdjustmentType__c = wrap.AdjustmenType;
        adjustmentLine.IMagic__Inventory__c = wrap.inventoryId;
        adjustmentLine.IMagic__Product__c = wrap.productId;
        adjustmentLine.IMagic__QuantityAdjusted__c = wrap.newQuantity;
        adjustmentLine.IMagic__StockAdjustment__c = adjustment.Id;
        return adjustmentLine;
    }

    public static IMagic__Transaction_History__c createInventoryTransaction(stockAdjustmentLineWrapper wrap,IMagic__Stock_Adjustment__c adjustment){
        IMagic__Transaction_History__c invTransaction = new IMagic__Transaction_History__c();
        invTransaction.IMagic__Type__c = 'Stock Adjustment';
        invTransaction.IMagic__Transaction_Date_Time__c = Datetime.now();
        invTransaction.IMagic__Source_Stocking_Location__c = wrap.stockingLocationId;
        invTransaction.IMagic__Inventory__c = wrap.inventoryId;
        invTransaction.IMagic__Product__c = wrap.productId;
        invTransaction.IMagic__Old_Inventory_Quantity_On_Hand__c = wrap.QuantityOnHand;
        invTransaction.IMagic__Quantity__c = wrap.newQuantity;
        invTransaction.IMagic__Adjustment_Type__c = wrap.AdjustmenType;
        invTransaction.IMagic__Stock_Adjustment__c = adjustment.Id;
        if(wrap.action == 'Add'){
            invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = wrap.QuantityOnHand + wrap.newQuantity;
        }
        else{
            invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = wrap.QuantityOnHand - wrap.newQuantity;
        }
        return invTransaction;
    }

    public static IMagic__Inventory__c createInventory(stockAdjustmentLineWrapper wrap,IMagic__Inventory__c inventory){
        IMagic__Inventory__c inv = new IMagic__Inventory__c();
        inv.Id = wrap.inventoryId;
        if(wrap.action == 'Add'){
            inv.IMagic__Quantity_on_Hand__c = inventory.IMagic__Quantity_on_Hand__c + wrap.newQuantity;
        }
        else{
            if(wrap.newQuantity <= inventory.IMagic__Quantity_on_Hand__c){
                inv.IMagic__Quantity_on_Hand__c = inventory.IMagic__Quantity_on_Hand__c - wrap.newQuantity;
            }
            else{
                throw new AuraHandledException('Failed to update, Not Much Quantity in Stock');
            }
        }
        return inv;
    }

    public class stockAdjustmentLineWrapper {
        @AuraEnabled public String rowNumber { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Boolean isSerialControlProduct { get; set; }
        @AuraEnabled public String stockingLocationId { get; set; }
        @AuraEnabled public String inventoryId { get; set; }
        @AuraEnabled public String inventoryName { get; set; }
        @AuraEnabled public Decimal QuantityOnHand { get; set; }
        @AuraEnabled public Decimal newQuantity { get; set; }
        @AuraEnabled public String action { get; set; }
        @AuraEnabled public String AdjustmenType { get; set; }
        @AuraEnabled public String adjustmentReason { get; set; }
        @AuraEnabled public List<serialListWrapper> serialList {get; set;}
        @AuraEnabled public List<serialNumberWrapper> serialNumberList {get; set;}
    }

    public class serialListWrapper {
        @AuraEnabled public String invDetailId { get; set; }
        @AuraEnabled public String invDetailName { get; set; }
    }

    public class serialNumberWrapper{
        @AuraEnabled public String purchaseOrderLineId {get; set;}
        @AuraEnabled public String serialNumber {get; set;}
    }
}