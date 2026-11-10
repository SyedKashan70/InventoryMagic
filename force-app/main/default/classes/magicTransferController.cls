public with sharing class magicTransferController {
    @AuraEnabled(cacheable=true)
    public static IMagic__Stocking_Location__c getMainWarehouseStockingLocation() {
        // Query the main warehouse stocking location
        try {
            IMagic__Stocking_Location__c mainWarehouseStock = [
                SELECT Id, Name, IMagic__Warehouse__c, IMagic__Warehouse__r.Name 
                FROM IMagic__Stocking_Location__c 
                WHERE IMagic__is_Main_Stocking_Location__c = true 
            LIMIT 1
        ];
            System.debug('mainWarehouseStock :: '+mainWarehouseStock);
        return mainWarehouseStock;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get getMainWarehouseStockingLocation :: ' + ex.getMessage());
        }
    }

    public static List<OrderItem> getOrderProducts(String warehouseId, String sourceLocationId,String destinationLocationId){
        try {
            List<OrderItem> listOrderItem = [SELECT Id, Order.Status,Order.Id, Order.OrderNumber, Quantity, IMagic__PO_Quantity__c, IMagic__Shipped_Quantity__c,IMagic__Transferred_Quantity__c,
            IMagic__Reserved_Quantity__c,IMagic__Transfer_Pending_Quantity__c, Product2Id, Product2.Name, Product2.RecordType.Name,IMagic__Stocking_Location__c 
                                            FROM OrderItem 
                                            WHERE Order.IMagic__Warehouse__c = :warehouseId 
                                            AND IMagic__Stocking_Location__c  = :sourceLocationId 
                                            AND Order.IMagic__Stocking_Location__c =: destinationLocationId
                                            AND Order.Status = 'Awaiting Magic' AND IMagic__Transfer_Pending_Quantity__c > 0 ORDER BY Order.OrderNumber];
            System.debug('listOrderItem ls' +listOrderItem);
            return listOrderItem;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get Order Products :: ' + ex.getMessage());
        }
    }
    

    public static Map<String,IMagic__Inventory__c> getInventoryRecords(Set<Id> productIds, String locationId) {
        // Query to get the inventory records based on product and stocking location
        try {
            List<IMagic__Inventory__c> inventoryRecords = [SELECT Id,Name, IMagic__Quantity_on_Hand__c,IMagic__Quantity_Reserved__c,IMagic__Product__c,IMagic__Stocking_Location__c,IMagic__Stocking_Location__r.Name
                                                    FROM IMagic__Inventory__c WHERE IMagic__Product__c IN: productIds AND IMagic__Stocking_Location__c = :locationId];
            Map<String,IMagic__Inventory__c> inventoryMap = new Map<String,IMagic__Inventory__c>();
            for(Inventory__c inv : inventoryRecords){
                String key = inv.Product__c + '::' + inv.IMagic__Stocking_Location__c;  
                inventoryMap.put(key,inv);
            }   
            return inventoryMap;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get related Inventory Record :: '+ex.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String,List<magicTransferLineWrapper>> processOrderProducts(String wareHouseId,String sourceLocationId,String destinationLocationId,String destinationLocationName){   
        Map<String,List<magicTransferLineWrapper>> mapOfWrapper = new Map<String,List<magicTransferLineWrapper>>();
        System.debug('wareHouseId :: '+wareHouseId);
        System.debug('sourceLocationId :: '+sourceLocationId);
        System.debug('destinationLocationId :: '+destinationLocationId);    
        List<OrderItem> relatedOrderItems = getOrderProducts(wareHouseId,sourceLocationId,destinationLocationId);
        System.debug('relatedOrderItems :: '+relatedOrderItems);    
        if(!relatedOrderItems.isEmpty()){
            Set<Id> productIds = new Set<Id>();
            for(OrderItem oi : relatedOrderItems){
                productIds.add(oi.Product2Id);
            }   
            System.debug('productIds :: '+productIds);  
            Map<String,IMagic__Inventory__c> sourceInventoryMap = getInventoryRecords(productIds,sourceLocationId);  
            Map<String,IMagic__Inventory__c> destinationInventoryMap = getInventoryRecords(productIds,destinationLocationId);  
            System.debug('Source InventoryMap :: '+sourceInventoryMap); 
            System.debug('Destination InventoryMap :: '+destinationInventoryMap);

            for(OrderItem oi : relatedOrderItems){
                System.debug('Name :: '+oi.Product2.Name);
                String sourceKey = oi.Product2Id + '::' + sourceLocationId;
                String destinationKey = oi.Product2Id + '::' + destinationLocationId;
                
                System.debug('sourceKey :: '+sourceKey); 
                System.debug('destinationKey :: '+destinationKey);

                magicTransferLineWrapper stlw = new magicTransferLineWrapper(); 
                stlw.orderItemId = oi.Id;
                stlw.orderItemQuantity = oi.Quantity != null ? oi.Quantity : 0;
                stlw.orderItemTransferredQuantity = oi.IMagic__Transferred_Quantity__c != null ? oi.IMagic__Transferred_Quantity__c : 0;
                stlw.orderItemTransferPendingQuantity = oi.IMagic__Transfer_Pending_Quantity__c != null ? oi.IMagic__Transfer_Pending_Quantity__c : 0;
                stlw.orderId = oi.Order.Id;
                stlw.orderNumber = oi.Order.OrderNumber;
                stlw.isSelected = false;
                stlw.selectedProductId = oi.Product2Id;
                stlw.selectedProductName = oi.Product2.Name;   
                stlw.isSerialControlProduct = oi.Product2.RecordType.Name == 'Serial Control' ? true : false;
                stlw.sourceStockingLocationId = sourceLocationId;
                stlw.sourceStockingLocationName = sourceInventoryMap.get(sourceKey) != null ? sourceInventoryMap.get(sourceKey).Stocking_Location__r.Name : '';
                stlw.destinationStockingLocationId = destinationLocationId;
                stlw.destinationStockingLocationName = destinationLocationName;
                stlw.sourceStockingLocationInventoryId = sourceInventoryMap.get(sourceKey) != null ? sourceInventoryMap.get(sourceKey).Id : '';
                stlw.sourceStockingLocationInventoryName = sourceInventoryMap.get(sourceKey) != null ? sourceInventoryMap.get(sourceKey).Name : '';  
                if (destinationInventoryMap.containsKey(destinationKey) && destinationInventoryMap.get(destinationKey) != null) {   
                    stlw.destinationStockingLocationInventoryId = destinationInventoryMap.get(destinationKey).Id;
                } else {
                    stlw.destinationStockingLocationInventoryId = ''; // or handle as needed
                }
                stlw.destinationStockingLocationInventoryName = destinationInventoryMap.get(destinationKey) != null ? destinationInventoryMap.get(destinationKey).Name : '';   
                stlw.sourceStockingLocationavailbleQuantity = sourceInventoryMap.get(sourceKey) != null ? sourceInventoryMap.get(sourceKey).IMagic__Quantity_Reserved__c : 0;
                stlw.destinationStockingLocationavailbleQuantity = destinationInventoryMap.get(destinationKey) != null ? destinationInventoryMap.get(destinationKey).IMagic__Quantity_Reserved__c : 0;
                stlw.transferQuantity = 0;
                stlw.serialList =  new List<serialListWrapper>();
                System.debug('stlw :: '+stlw); 

                List<magicTransferLineWrapper> listOfWrapper = new List<magicTransferLineWrapper>();  
                if(mapOfWrapper.containsKey(oi.Order.OrderNumber)){
                    listOfWrapper = mapOfWrapper.get(oi.Order.OrderNumber);
                }
                listOfWrapper.add(stlw);
                System.debug('listOfWrapper :: '+listOfWrapper);
                mapOfWrapper.put(oi.Order.OrderNumber,listOfWrapper);
            }  
        }
        return mapOfWrapper;
    }

    public static IMagic__Magic_Transfer__c insertMagicTransfer(String wareHouseId){
        try {
            IMagic__Magic_Transfer__c Transfer = new IMagic__Magic_Transfer__c();
            Transfer.Warehouse__c = wareHouseId;
            Transfer.IMagic__Status__c = 'Delivered';
            Transfer.IMagic__Transfer_Date__c = Date.today();
            insert Transfer;
            return Transfer;
        } catch (Exception e) {
            System.debug('e.getMessage() :: '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    
    public static IMagic__Magic_Transfer_Line_Item__c createMagicTransferLine(magicTransferLineWrapper line,IMagic__Magic_Transfer__c magicTransferObj){
        try {
            IMagic__Magic_Transfer_Line_Item__c magicTransferLine = new IMagic__Magic_Transfer_Line_Item__c();
            magicTransferLine.IMagic__Product__c = line.selectedProductId;
            magicTransferLine.IMagic__Quantity_Available__c = line.sourceStockingLocationavailbleQuantity;
            magicTransferLine.IMagic__Quantity_Transferred__c = line.transferQuantity;
            magicTransferLine.IMagic__Magic_Transfer__c = magicTransferObj.Id;
            magicTransferLine.IMagic__Source_Stocking_Location__c = line.sourceStockingLocationId;
            magicTransferLine.IMagic__Destination_Stocking_Location__c = line.destinationStockingLocationId;
            magicTransferLine.IMagic__Order__c = line.orderId;
            magicTransferLine.IMagic__Order_Product__c = line.orderItemId;
            return magicTransferLine;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static List<Inventory__c> getRelatedInvList(Set<Id> invIds){
        List<IMagic__Inventory__c> LstOfInv = new List<IMagic__Inventory__c>([SELECT Id,name,IMagic__Product__c,IMagic__Stocking_Location__c,
                                                                            IMagic__Quantity_on_Hand__c,IMagic__Stocking_Location__r.Name,
                                                                            IMagic__Cost__c,IMagic__Quantity_Reserved__c
                                                                            FROM IMagic__Inventory__c WHERE Id IN :invIds]);
        return LstOfInv;                                                                     
    }

    public static IMagic__Inventory__c createInventory(String name,Id stockkingLocationId,Id productId){
        IMagic__Inventory__c inventory = new IMagic__Inventory__c();
        inventory.Name = name;
        inventory.IMagic__Quantity_on_Hand__c = 0;
        inventory.IMagic__Stocking_Location__c = stockkingLocationId;
        inventory.IMagic__Product__c = productId;
        return inventory;
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

    public static List<IMagic__Inventory_Detail__c> createInventoryDetailList(magicTransferLineWrapper line,Id destinationInvId){
        try {
            List<IMagic__Inventory_Detail__c> list_InvDetail = new List<IMagic__Inventory_Detail__c>();
            for(serialListWrapper serial : line.serialList){
                IMagic__Inventory_Detail__c invDetail = new IMagic__Inventory_Detail__c();
                invDetail.Id = serial.invDetailId;
                invDetail.IMagic__Inventory__c = destinationInvId;
                invDetail.IMagic__Order_Product__c = line.orderItemId;
                list_InvDetail.add(invDetail);
            }
            return list_InvDetail;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static IMagic__Transaction_History__c createInventoryTransaction(magicTransferLineWrapper line, IMagic__Inventory__c inv,String type){
        IMagic__Transaction_History__c invTransaction = new IMagic__Transaction_History__c();
        invTransaction.IMagic__Type__c = 'Magic Transfer';
        invTransaction.IMagic__Transaction_Date_Time__c = Datetime.now();
        invTransaction.IMagic__Source_Stocking_Location__c = line.sourceStockingLocationId;
        invTransaction.IMagic__Destination_Stocking_Location__c = line.destinationStockingLocationId;
        invTransaction.IMagic__Inventory__c = inv.Id;
        invTransaction.IMagic__Product__c = line.selectedProductId;
        invTransaction.IMagic__Order_Product__c = line.orderItemId;
        invTransaction.IMagic__Old_Inventory_Quantity_Reserved__c = inv.Quantity_Reserved__c;
        invTransaction.IMagic__Old_Inventory_Quantity_On_Hand__c = inv.IMagic__Quantity_on_Hand__c;
        invTransaction.IMagic__Quantity__c = line.transferQuantity;
        invTransaction.IMagic__Magic_Transaction_Type__c = type;
        return invTransaction;
    }

    @AuraEnabled
    public static Id createMagicTransfer_LineItem(String wareHouseId,String transferJson){
        try {
            List<Magic_Transfer_Line_Item__c> magicTransferLineList = new List<Magic_Transfer_Line_Item__c>();
            List<IMagic__Inventory_Detail__c> invDetailList_Update = new List<IMagic__Inventory_Detail__c>();
            Set<Id> invIds = new Set<Id>();
            Map<String, IMagic__Inventory__c> MapOfInv = new Map<String, IMagic__Inventory__c>();
            List<IMagic__Inventory__c> invListtoInsert = new List<IMagic__Inventory__c>();// For creating new Destination Stocking Location Inv if not Exist
            List<IMagic__Inventory__c> invListtoUpdate = new List<IMagic__Inventory__c>();// For Updating the Values
            List<OrderItem> orderItemUpdate = new List<OrderItem>();
            List<IMagic__Transaction_History__c> invTransactionList = new List<IMagic__Transaction_History__c>();
            Map<Id,IMagic__Transaction_History__c> destinationInvTransactionMap = new Map<Id,IMagic__Transaction_History__c>();

            List<magicTransferLineWrapper> magicTransferLineWrapperList = (List<magicTransferLineWrapper>) JSON.deserialize(transferJson, List<magicTransferLineWrapper>.class); 
            
            IMagic__Magic_Transfer__c magicTransferObj = insertMagicTransfer(wareHouseId);
            System.debug('stockTransfer :: '+magicTransferObj);

            for(magicTransferLineWrapper line : magicTransferLineWrapperList){
                magicTransferLineList.add(createMagicTransferLine(line,magicTransferObj));
                invIds.add(line.sourceStockingLocationInventoryId);
                if(line.destinationStockingLocationInventoryId != null && line.destinationStockingLocationInventoryId != ''){
                    invIds.add(line.destinationStockingLocationInventoryId);
                }
            }

            

            System.debug('magicTransferLineList :: '+magicTransferLineList);
            if(!magicTransferLineList.isEmpty()){
                insert magicTransferLineList;
                System.debug('magicTransferLineList inserted');
            }

            List<IMagic__Inventory__c> relatedInentories = getRelatedInvList(invIds);
            
            for (IMagic__Inventory__c Inv : relatedInentories) {
                String key =  Inv.IMagic__Product__c + '::' + Inv.IMagic__Stocking_Location__c;
                MapOfInv.put(key, Inv);
            }

            for(magicTransferLineWrapper line : magicTransferLineWrapperList){
                String key = line.selectedProductId + '::' + line.destinationStockingLocationId;
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
                for (IMagic__Inventory__c Inv : invListtoInsert) {
                    String key = Inv.IMagic__Product__c + '::' + Inv.IMagic__Stocking_Location__c;
                    MapOfInv.put(key, Inv);
                }
            }

            
            System.debug('Updating Inv Values');

            for(magicTransferLineWrapper line : magicTransferLineWrapperList){
                String destinationInvkey = line.selectedProductId + '::' + line.destinationStockingLocationId;
                String sourceInvkey = line.selectedProductId + '::' + line.sourceStockingLocationId;
                System.debug('destinationInvkey :: '+destinationInvkey);
                System.debug('sourceInvkey :: '+sourceInvkey);
                IMagic__Inventory__c sourceInv = initializeInventory(sourceInvkey,MapOfInv);
                IMagic__Inventory__c destinationInv = initializeInventory(destinationInvkey,MapOfInv);

                System.debug('sourceInv :: '+sourceInv);
                System.debug('destinationInv :: '+destinationInv);


                IMagic__Transaction_History__c sourceInvTransaction = createInventoryTransaction(line,sourceInv,'Source Transaction');
                IMagic__Transaction_History__c destinationInvTransaction = createInventoryTransaction(line,destinationInv,'Destination Transaction');
                

                //Updating Values
                sourceInv.IMagic__Quantity_Reserved__c -= line.transferQuantity;
                destinationInv.IMagic__Quantity_Reserved__c += line.transferQuantity;
                destinationInv.IMagic__Cost__c = sourceInv.IMagic__Cost__c;

                
                sourceInvTransaction.IMagic__New_Inventory_Quantity_Reserved__c = sourceInv.IMagic__Quantity_Reserved__c;
                sourceInvTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = sourceInv.IMagic__Quantity_on_Hand__c;

                destinationInvTransaction.IMagic__New_Inventory_Quantity_Reserved__c = destinationInv.IMagic__Quantity_Reserved__c;
                destinationInvTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = destinationInv.IMagic__Quantity_on_Hand__c;

                // invListtoUpdate.add(sourceInv);
                // invListtoUpdate.add(destinationInv); 
                System.debug('sourceInv after :: '+sourceInv);
                System.debug('destinationInv after :: '+destinationInv);
                MapOfInv.put(sourceInvkey,sourceInv);
                MapOfInv.put(destinationInvkey,destinationInv);

                destinationInvTransactionMap.put(line.orderItemId,destinationInvTransaction);
                
                invTransactionList.add(sourceInvTransaction);
                invTransactionList.add(destinationInvTransaction);

                if(line.isSerialControlProduct){
                    invDetailList_Update.addAll(createInventoryDetailList(line,destinationInv.Id));
                }

                OrderItem oi = new OrderItem();
                oi.Id = line.orderItemId;
                // oi.IMagic__Stocking_Location__c = line.destinationStockingLocationId;
                oi.IMagic__Transferred_Quantity__c = line.orderItemTransferredQuantity + line.transferQuantity;
                orderItemUpdate.add(oi);
            }


            if(MapOfInv != null){
                invListtoUpdate = MapOfInv.values();
            }

            if(!invListtoUpdate.isEmpty()){
                update invListtoUpdate;
            }

            if(!orderItemUpdate.isEmpty()){
                update orderItemUpdate;
            }

            if(!invTransactionList.isEmpty()){
                insert invTransactionList;
            }

            if(!invDetailList_Update.isEmpty()){
                for(IMagic__Inventory_Detail__c detail : invDetailList_Update){
                    if(destinationInvTransactionMap != null){
                        detail.IMagic__Inventory_Transaction__c = destinationInvTransactionMap.get(detail.IMagic__Order_Product__c).Id;    
                    }
                }
                update invDetailList_Update;
            }
            
            return magicTransferObj.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    

    public class magicTransferLineWrapper {
        @AuraEnabled public String orderId { get; set; }
        @AuraEnabled public String orderNumber { get; set; }
        @AuraEnabled public String orderItemId { get; set; }
        @AuraEnabled public Decimal orderItemQuantity { get; set; }
        @AuraEnabled public Decimal orderItemTransferredQuantity { get; set; }
        @AuraEnabled public Decimal orderItemTransferPendingQuantity { get; set; }
        @AuraEnabled public Boolean isSelected { get; set; }
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
        @AuraEnabled public Decimal destinationStockingLocationavailbleQuantity { get; set; }
        @AuraEnabled public Decimal transferQuantity { get; set; }
        @AuraEnabled public List<serialListWrapper> serialList {get; set;}
    }

    public class serialListWrapper {
        @AuraEnabled public String invDetailId { get; set; }
        @AuraEnabled public String invDetailName { get; set; }
    }
    
}