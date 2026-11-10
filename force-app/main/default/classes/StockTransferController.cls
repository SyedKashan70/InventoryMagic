public with sharing class StockTransferController {
	@AuraEnabled
    public static IMagic__Inventory__c getInventoryRecords(String productId, String stockingLocationId) {
        // Query to get the inventory records based on product and stocking location
        try {
            IMagic__Inventory__c inv_to_return = new IMagic__Inventory__c();
            List<IMagic__Inventory__c> inventoryRecords = [
            SELECT Id,Name, IMagic__Quantity_on_Hand__c 
            FROM IMagic__Inventory__c 
            WHERE IMagic__Product__c = :productId 
            AND IMagic__Stocking_Location__c = :stockingLocationId LIMIT 1
            ];
            if(!inventoryRecords.isEmpty()){
                inv_to_return = inventoryRecords[0];
            }
            return inv_to_return;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get related Inventory Record :: '+ex.getMessage());
        }
    }
    @AuraEnabled
    public static Id createStockTransfer_LineItem(String sourceWarehouseId,String destinationWarehouseId,Boolean isMultiWarehouseTransfer,String transferJson){
        try {
            List<IMagic__Stock_Transfer_Line_Item__c> stockTransferLineList = new List<IMagic__Stock_Transfer_Line_Item__c>();
            List<IMagic__Inventory_Detail__c> invDetailList_Update = new List<IMagic__Inventory_Detail__c>();
            Set<Id> invIds = new Set<Id>();
            Map<String, IMagic__Inventory__c> MapOfInv = new Map<String, IMagic__Inventory__c>();
            List<IMagic__Inventory__c> invListtoInsert = new List<IMagic__Inventory__c>();// For creating new Destination Stocking Location Inv if not Exist
            List<IMagic__Inventory__c> invListtoUpdate = new List<IMagic__Inventory__c>();// For Updating the Values

            List<stockTransferLineWrapper> stockTransferLineWrapperList = (List<stockTransferLineWrapper>) JSON.deserialize(transferJson, List<stockTransferLineWrapper>.class); 
            System.debug('sourceWarehouseId :: '+sourceWarehouseId);
            System.debug('destinationWarehouseId :: '+destinationWarehouseId);
            System.debug('isMultiWarehouseTransfer :: '+isMultiWarehouseTransfer);
            System.debug('stockTransferLineWrapperList :: '+stockTransferLineWrapperList);
            
            IMagic__Stock_Transfer__c stockTransferObj = insertStockTransfer(sourceWarehouseId,destinationWarehouseId);
            System.debug('stockTransfer :: '+stockTransferObj);

            for(stockTransferLineWrapper line : stockTransferLineWrapperList){
                stockTransferLineList.add(createStockTransferLine(line,stockTransferObj));
                invIds.add(line.sourceStockingLocationInventoryId);
                if(line.destinationStockingLocationInventoryId != null && line.destinationStockingLocationInventoryId != ''){
                    invIds.add(line.destinationStockingLocationInventoryId);
                }
            }

            

            System.debug('stockTransferLineList :: '+stockTransferLineList);
            if(!stockTransferLineList.isEmpty()){
                insert stockTransferLineList;
                System.debug('stockTransferLineList inserted');
            }

            List<IMagic__Inventory__c> relatedInentories = getRelatedInvList(invIds);
            
            for (IMagic__Inventory__c Inv : relatedInentories) {
                String key = Inv.Stocking_Location__c + '::' + Inv.Product__c;
                MapOfInv.put(key, Inv);
            }

            for(stockTransferLineWrapper line : stockTransferLineWrapperList){
                String key = line.destinationStockingLocationId + '::' + line.selectedProductId;
                if(!MapOfInv.containsKey(key)){
                  System.debug('creating destination Inventory');
                  String newInvName = line.destinationStockingLocationName + ' - ' + line.selectedProductName;
                  IMagic__Inventory__c inv = createInventory(newInvName,line.destinationStockingLocationId,line.selectedProductId);
                  invListtoInsert.add(inv);
                }
                else {
                  System.debug('Inventory exist');
                }
            }

            System.debug('invListtoInsert :: '+invListtoInsert);
            if(!invListtoInsert.isEmpty()){
                insert invListtoInsert;
                System.debug('invListtoInsert inserted');
                 //Adding newly created Inventories in Map
                for (Inventory__c Inv : invListtoInsert) {
                    String key = Inv.Stocking_Location__c + '::' + Inv.Product__c;
                    MapOfInv.put(key, Inv);
                }
            }

           
            System.debug('Updating Inv Values');

            for(stockTransferLineWrapper line : stockTransferLineWrapperList){
                String destinationInvkey = line.destinationStockingLocationId + '::' + line.selectedProductId;
                String sourceInvkey = line.sourceStockingLocationId + '::' + line.selectedProductId;
                System.debug('destinationInvkey :: '+destinationInvkey);
                System.debug('sourceInvkey :: '+sourceInvkey);
                IMagic__Inventory__c sourceInv = initializeInventory(sourceInvkey,MapOfInv);
                IMagic__Inventory__c destinationInv = initializeInventory(destinationInvkey,MapOfInv);

                System.debug('sourceInv :: '+sourceInv);
                System.debug('destinationInv :: '+destinationInv);

                sourceInv.IMagic__Quantity_on_Hand__c -= line.transferQuantity;
                destinationInv.IMagic__Quantity_on_Hand__c += line.transferQuantity;

                invListtoUpdate.add(sourceInv);
                invListtoUpdate.add(destinationInv);

                if(line.isSerialControlProduct){
                    invDetailList_Update.addAll(createInventoryDetailList(line,destinationInv.Id));
                }
            }
            System.debug('invListtoUpdate :: '+invListtoUpdate);
            if(!invListtoUpdate.isEmpty()){
                update invListtoUpdate;
                System.debug('invListtoUpdate updated');
            }

            System.debug('invDetailList_Update :: '+invDetailList_Update);
            if(!invDetailList_Update.isEmpty()){
                update invDetailList_Update;
                System.debug('invDetailList_Update updated');
            }
            return stockTransferObj.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static IMagic__Stock_Transfer__c insertStockTransfer(String sourceInvId,String destinationInvId){
        try {
            System.debug('insertStockTransfer => destinationInvId : '+destinationInvId);
            System.debug('insertStockTransfer => sourceInvId : '+sourceInvId);
            IMagic__Stock_Transfer__c stockTransfer = new IMagic__Stock_Transfer__c();
            stockTransfer.Source_Warehouse__c = sourceInvId;
            if(destinationInvId != null && destinationInvId != ''){
                System.debug('Not Destination warehouse');
                stockTransfer.IMagic__Destination_Warehouse__c = destinationInvId;
            }
            stockTransfer.IMagic__Status__c = 'Delivered';
            stockTransfer.IMagic__Transfer_Date__c = Date.today();
            insert stockTransfer;
            return stockTransfer;
        } catch (Exception e) {
            System.debug('e.getMessage() :: '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static IMagic__Stock_Transfer_Line_Item__c createStockTransferLine(stockTransferLineWrapper line,IMagic__Stock_Transfer__c stockTransferObj){
        try {
            IMagic__Stock_Transfer_Line_Item__c stockTransferLine = new IMagic__Stock_Transfer_Line_Item__c();
            stockTransferLine.IMagic__Product__c = line.selectedProductId;
            stockTransferLine.IMagic__Quantity__c = line.transferQuantity;
            stockTransferLine.IMagic__Stock_Transfer__c = stockTransferObj.Id;
            stockTransferLine.IMagic__Stocking_Location_Source__c = line.sourceStockingLocationId;
            stockTransferLine.IMagic__Stocking_Location_Destination__c = line.destinationStockingLocationId;
            return stockTransferLine;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static IMagic__Inventory__c createInventory(String name,Id stockkingLocationId,Id productId){
        IMagic__Inventory__c inventory = new IMagic__Inventory__c();
        inventory.Name = name;
        inventory.IMagic__Quantity_on_Hand__c = 0;
        inventory.IMagic__Stocking_Location__c = stockkingLocationId;
        inventory.IMagic__Product__c = productId;
        return inventory;
    }

    public static List<IMagic__Inventory__c> getRelatedInvList(Set<Id> invIds){
        List<IMagic__Inventory__c> LstOfInv = new List<IMagic__Inventory__c>([SELECT Id,name,IMagic__Product__c,IMagic__Stocking_Location__c,
                                                                            IMagic__Quantity_on_Hand__c,IMagic__Stocking_Location__r.Name,
                                                                            IMagic__Cost__c,IMagic__Quantity_Reserved__c
                                                                            FROM IMagic__Inventory__c WHERE Id IN :invIds]);
        return LstOfInv;                                                                     
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

    public static List<IMagic__Inventory_Detail__c> createInventoryDetailList(stockTransferLineWrapper line,Id destinationInvId){
        try {
            List<IMagic__Inventory_Detail__c> list_InvDetail = new List<IMagic__Inventory_Detail__c>();
            for(serialListWrapper serial : line.serialList){
                IMagic__Inventory_Detail__c invDetail = new IMagic__Inventory_Detail__c();
                invDetail.Id = serial.invDetailId;
                invDetail.IMagic__Inventory__c = destinationInvId;
                list_InvDetail.add(invDetail);
            }
            return list_InvDetail;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class stockTransferLineWrapper {
        @AuraEnabled public String selectedProductId { get; set; }
        @AuraEnabled public String selectedProductName { get; set; }
        @AuraEnabled public Boolean isSerialControlProduct { get; set; }
        @AuraEnabled public String sourceStockingLocationId { get; set; }
        @AuraEnabled public String sourceStockingLocationName { get; set; }
        @AuraEnabled public String sourceStockingLocationInventoryId { get; set; }
        @AuraEnabled public String sourceStockingLocationInventoryName { get; set; }
        @AuraEnabled public String destinationStockingLocationId { get; set; }
        @AuraEnabled public String destinationStockingLocationName { get; set; }
        @AuraEnabled public String destinationStockingLocationInventoryId { get; set; }
        @AuraEnabled public String destinationStockingLocationInventoryName { get; set; }
        @AuraEnabled public Decimal sourceStockingLocationavailbleQuantity { get; set; }
        @AuraEnabled public String destinationStockingLocationavailbleQuantity { get; set; }
        @AuraEnabled public Decimal transferQuantity { get; set; }
        @AuraEnabled public String description {get; set;}
        @AuraEnabled public List<serialListWrapper> serialList {get; set;}
    }

    public class serialListWrapper {
        @AuraEnabled public String invDetailId { get; set; }
        @AuraEnabled public String invDetailName { get; set; }
    }
  }