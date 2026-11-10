public without sharing class PurchaseOrderLinesController {
    @AuraEnabled(cacheable=true)
    public static Lodestone__Purchase_Order__c  getPurchaseOrder(Id purchaseOrderId) {
       try {
        Lodestone__Purchase_Order__c  po = [SELECT Id, Lodestone__Order__c FROM Lodestone__Purchase_Order__c  WHERE Id = :purchaseOrderId];
        System.debug('po :: '+po);
        return po;
       } catch (Exception ex) {
        
        System.debug(' Error While Getting PO'+ex.getMessage());
        throw new AuraHandledException(ex.getMessage());
       }


    }


    @AuraEnabled(cacheable=true)
    public static List<purchaseOrderLineWrapper> getPurchaseOrderLines(Id purchaseOrderId) {
        try {
            List<Lodestone__Purchase_Order_Line__c> POLI_List = [SELECT Id, Lodestone__Quantity__c,IMagic__Received_Quantity__c,
            										  Lodestone__Cost_Price__c,Lodestone__Product__c, Lodestone__Product__r.Name,Lodestone__Product__r.Lodestone__Cost_Price__c,Lodestone__Purchase_Order__c ,
                                                      Lodestone__Product__r.RecordType.Name,Lodestone__Product__r.Description,
                                                      IMagic__Inventory__c,IMagic__Inventory__r.IMagic__Cost__c,Lodestone__Product__r.IMagic__Warehouse__r.IMagic__Costing_Method__c,
                                                      Lodestone__Order_Product__c , IMagic__Lodestone_Stocking_Location__c,IMagic__Received__c ,
                                                      Lodestone__Purchase_Order__r.RecordType.Name 
                                                      FROM Lodestone__Purchase_Order_Line__c WHERE 
                                                      Lodestone__Purchase_Order__c  = :purchaseOrderId and IMagic__Received__c  =  false];
        List<purchaseOrderLineWrapper> wrapperList = new List<purchaseOrderLineWrapper>();
        System.debug('POLI_List :: '+POLI_List);
        for(Lodestone__Purchase_Order_Line__c poli : POLI_List){
            purchaseOrderLineWrapper wrap = new purchaseOrderLineWrapper();
            wrap.Id = poli.Id;
            wrap.quantityOrdered = poli.Lodestone__Quantity__c;
            wrap.recievedQuantity = poli.IMagic__Received_Quantity__c;
            wrap.newQuantity = 0;
            wrap.unitPrice = poli.IMagic__Inventory__r.IMagic__Cost__c	;
            // wrap.unitPrice = poli.Lodestone__Cost_Price__c;
            wrap.productId = poli.Lodestone__Product__c;
            wrap.productName = poli.Lodestone__Product__r.Name;
            wrap.productCost = poli.Lodestone__Product__r.Lodestone__Cost_Price__c;
            wrap.productDescription = poli.Lodestone__Product__r.Description;
            wrap.productRecordTypeName = poli.Lodestone__Product__r.RecordType.Name;
            wrap.isSerialControlProduct = poli.Lodestone__Product__r.RecordType.Name == 'Serial Control' ? true : false;
            wrap.serialNumberList = new List<serialNumberWrapper>();
            System.debug('poli.IMagic__Inventory__c :: '+poli.IMagic__Inventory__c);
            wrap.inventoryId = poli.IMagic__Inventory__c;
            wrap.inventoryCost = poli.IMagic__Inventory__r.IMagic__Cost__c;
            wrap.orderProduct = poli.Lodestone__Order_Product__c;
            wrap.stockingLocation = poli.IMagic__Lodestone_Stocking_Location__c;
            wrap.purchaseOrderRecordTypeName = poli.Lodestone__Purchase_Order__r.RecordType.Name;
            System.debug('poli.Product__r.IMagic__Warehouse__r.IMagic__Costing_Method__c :: '+poli.Lodestone__Product__r.IMagic__Warehouse__r.IMagic__Costing_Method__c);
            wrap.calculateAveragePriceForInv = poli.Lodestone__Product__r.IMagic__Warehouse__r.IMagic__Costing_Method__c == 'Average Purchase Price' ? true : false;
            wrapperList.add(wrap);
        }
        return wrapperList;
        } catch (Exception ex) {
            
            System.debug(' Error While Getting PO Line'+ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }

  
    @AuraEnabled
    public static Id updatePurchaseOrderLines(String orderLinesJSON,String purchaseOrderId){
        try {
            List<Lodestone__Purchase_Order_Line__c> POLines_Update = new List<Lodestone__Purchase_Order_Line__c>();
            List<IMagic__Receiving__c> recievingList_Insert = new List<IMagic__Receiving__c>();
            List<OrderItem> orderItemList_Update = new List<OrderItem>();
            List<IMagic__Inventory__c> inventoryList_Update = new List<IMagic__Inventory__c>();
            List<IMagic__Inventory_Detail__c> inventoryDetailList_Insert = new List<IMagic__Inventory_Detail__c>();
            List<IMagic__Purchase_Order_Line_Detail__c> purchaseOrderLineDetailList_Insert = new List<IMagic__Purchase_Order_Line_Detail__c>();
            Map<Id,Transaction_History__c> invTransactionMap = new Map<Id,Transaction_History__c>();
            List<purchaseOrderLineWrapper> orderLineWrapperList = (List<purchaseOrderLineWrapper>) JSON.deserialize(orderLinesJSON, List<purchaseOrderLineWrapper>.class); 

    
            Set<Id> orderProductIds = new Set<Id>();
            Set<Id> inventoryIds = new Set<Id>();
            for (purchaseOrderLineWrapper wrap : orderLineWrapperList) {
                
                if (wrap.orderProduct != null && wrap.orderProduct != '') {
                    orderProductIds.add(wrap.orderProduct);
                }
                
                if (wrap.inventoryId != null && wrap.inventoryId != '') {
                    inventoryIds.add(wrap.inventoryId);
                }

            }

    
            Map<Id, OrderItem> orderProductMap = new Map<Id, OrderItem>([SELECT Id, IMagic__Reserved_Quantity__c,IMagic__PO_Quantity__c,IMagic__Shipped_Quantity__c
                                                                        FROM OrderItem WHERE Id IN :orderProductIds]);
    
            Map<Id, IMagic__Inventory__c> inventoryMap = new Map<Id, IMagic__Inventory__c>([SELECT Id,IMagic__Quantity_on_Hand__c,IMagic__Cost__c,
                                                                                    IMagic__Quantity_Reserved__c FROM IMagic__Inventory__c
                                                                                    WHERE Id IN :inventoryIds]);
    
            
    
            System.debug('vinventoryMap before :: '+inventoryMap);
            for(purchaseOrderLineWrapper wrap : orderLineWrapperList){
                if((wrap.newQuantity + wrap.recievedQuantity) > wrap.quantityOrdered){
                    throw new AuraHandledException('Failed to update the Purchased Order Lines');
                }
                else{
                    System.debug('here 9');
                    Lodestone__Purchase_Order_Line__c pol = new Lodestone__Purchase_Order_Line__c();
                    pol.Id = wrap.Id;
                    pol.IMagic__Received_Quantity__c = (wrap.newQuantity + wrap.recievedQuantity);
                    pol.Lodestone__Cost_Price__c = wrap.unitPrice != null ? wrap.unitPrice : 0;
                    POLines_Update.add(pol);

                    System.debug('here 9');
                    //Create Purchase Order Line Details
                    if(wrap.isSerialControlProduct){
                        for(serialNumberWrapper serial : wrap.serialNumberList){
                            IMagic__Purchase_Order_Line_Detail__c purchaseOrderLineDetail = new IMagic__Purchase_Order_Line_Detail__c();
                            purchaseOrderLineDetail.IMagic__Purchase_Order_Line__c = wrap.Id;
                            purchaseOrderLineDetail.IMagic__Serial_Number__c = serial.serialNumber;
                            purchaseOrderLineDetail.IMagic__Quantity__c = 1;
                            purchaseOrderLineDetailList_Insert.add(purchaseOrderLineDetail);
                        }
                    }
                    
                    System.debug('here 9');
    
                    Decimal Qty = wrap.newQuantity;
                    IMagic__Inventory__c inventory = new IMagic__Inventory__c();
                    if(wrap.inventoryId != null && wrap.inventoryId != ''){
                        // inventory = inventoryMap.get(wrap.inventoryId);
                        inventory.Id = inventoryMap.get(wrap.inventoryId).Id;
                        inventory.IMagic__Quantity_on_Hand__c = inventoryMap.get(wrap.inventoryId).IMagic__Quantity_on_Hand__c != null ? inventoryMap.get(wrap.inventoryId).IMagic__Quantity_on_Hand__c : 0;
                        inventory.IMagic__Cost__c = inventoryMap.get(wrap.inventoryId).IMagic__Cost__c != null ? inventoryMap.get(wrap.inventoryId).IMagic__Cost__c : 0;
                        inventory.IMagic__Quantity_Reserved__c = inventoryMap.get(wrap.inventoryId).IMagic__Quantity_Reserved__c != null ? inventoryMap.get(wrap.inventoryId).IMagic__Quantity_Reserved__c : 0;
                    }

                    System.debug('wrap.calculateAveragePriceForInv :: '+wrap.calculateAveragePriceForInv);
                    if(wrap.calculateAveragePriceForInv) {
                        inventory.IMagic__Cost__c = ((inventory.IMagic__Quantity_on_Hand__c * inventory.IMagic__Cost__c) + (wrap.newQuantity * wrap.unitPrice)) / (inventory.IMagic__Quantity_on_Hand__c + wrap.newQuantity);
                        
                    } else {
                        inventory.IMagic__Cost__c = wrap.unitPrice;
                    }


                    
                    System.debug('here wrap.orderProduct '+wrap.orderProduct);
                    System.debug('wrap :: '+wrap);
                    IMagic__Transaction_History__c invTransaction = new IMagic__Transaction_History__c();
                    invTransaction.IMagic__Type__c = 'Recieve Purchase Order';
                    invTransaction.IMagic__Transaction_Date_Time__c = Datetime.now();
                    invTransaction.IMagic__Source_Stocking_Location__c = wrap.stockingLocation;
                    invTransaction.IMagic__Inventory__c = wrap.inventoryId;
                    invTransaction.IMagic__Product__c = wrap.productId;
                    invTransaction.IMagic__Order_Product__c = (wrap.orderProduct != null && wrap.orderProduct != '') ? wrap.orderProduct : null;
                    invTransaction.IMagic__Purchase_OrderLine_Item__c = wrap.Id;
                    invTransaction.IMagic__Old_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
                    invTransaction.Old_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                    invTransaction.IMagic__Quantity__c = wrap.newQuantity;
    
                    System.debug('here 91');
                    Integer serialNumberListIndex = 0;
                    if(wrap.orderProduct != null && wrap.orderProduct != ''){
                        // OrderItem ordItem = orderProductMap.get(wrap.orderProduct);
                        OrderItem orderItem_Update = new OrderItem();
                        orderItem_Update.Id = orderProductMap.get(wrap.orderProduct).Id;
                        orderItem_Update.IMagic__PO_Quantity__c = orderProductMap.get(wrap.orderProduct)?.IMagic__PO_Quantity__c != null ? orderProductMap.get(wrap.orderProduct).IMagic__PO_Quantity__c : 0;
                        orderItem_Update.IMagic__Reserved_Quantity__c = orderProductMap.get(wrap.orderProduct)?.IMagic__Reserved_Quantity__c != null ? orderProductMap.get(wrap.orderProduct).IMagic__Reserved_Quantity__c : 0;
                        orderItem_Update.IMagic__Shipped_Quantity__c = orderProductMap.get(wrap.orderProduct)?.IMagic__Shipped_Quantity__c != null ? orderProductMap.get(wrap.orderProduct).IMagic__Shipped_Quantity__c : 0;

                        invTransaction.IMagic__Old_Reserved_Quantity__c = orderItem_Update.IMagic__Reserved_Quantity__c;
                        invTransaction.IMagic__Old_PO_Quantity__c = orderItem_Update.IMagic__PO_Quantity__c;
                        
                        if(orderItem_Update.IMagic__PO_Quantity__c <= Qty){
                            Qty = (Qty - orderItem_Update.IMagic__PO_Quantity__c);
                            orderItem_Update.IMagic__Reserved_Quantity__c += orderItem_Update.IMagic__PO_Quantity__c;
                            inventory.IMagic__Quantity_Reserved__c += orderItem_Update.IMagic__PO_Quantity__c;
                            if(wrap.purchaseOrderRecordTypeName == 'Dropship PO'){      
                                orderItem_Update.IMagic__Shipped_Quantity__c += orderItem_Update.IMagic__PO_Quantity__c;
                            }
                            orderItem_Update.IMagic__PO_Quantity__c = 0;

                            invTransaction.IMagic__New_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
                            invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                            invTransaction.IMagic__New_Reserved_Quantity__c = orderItem_Update.IMagic__Reserved_Quantity__c;
                            invTransaction.IMagic__New_PO_Quantity__c = 0;
                        }
                        else{
                            orderItem_Update.IMagic__Reserved_Quantity__c += Qty;
                            inventory.IMagic__Quantity_Reserved__c += Qty;
                            if(wrap.purchaseOrderRecordTypeName == 'Dropship PO'){      
                                orderItem_Update.IMagic__Shipped_Quantity__c += Qty;
                            }
                            orderItem_Update.IMagic__PO_Quantity__c = (orderItem_Update.IMagic__PO_Quantity__c - Qty);
                            Qty = 0;

                            invTransaction.IMagic__New_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
                            invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                            invTransaction.IMagic__New_PO_Quantity__c = orderItem_Update.IMagic__PO_Quantity__c;
                            invTransaction.IMagic__New_Reserved_Quantity__c = orderItem_Update.IMagic__Reserved_Quantity__c;
                        }
                        orderItem_Update.UnitPrice = wrap.unitPrice != null ? wrap.unitPrice : 0;
                        orderItemList_Update.add(orderItem_Update);
                        invTransactionMap.put(wrap.inventoryId,invTransaction);

                        //Adding Inventory Detail record for Those which are directly added in Order
                        if(wrap.isSerialControlProduct){
                           System.debug('wrap.newQuantity ;; '+wrap.newQuantity);
                            System.debug('Qty :: '+Qty);
                            for(Integer i = 0;i < (wrap.newQuantity - Qty);i++){
                                IMagic__Inventory_Detail__c inventoryDetail = new IMagic__Inventory_Detail__c();
                                inventoryDetail.IMagic__Inventory__c = wrap.inventoryId;
                                inventoryDetail.Name = wrap.serialNumberList[serialNumberListIndex].serialNumber;
                                inventoryDetail.IMagic__Serial_Number__c = wrap.serialNumberList[serialNumberListIndex].serialNumber;
                                inventoryDetail.IMagic__Quantity_on_order__c = 1;    
                                inventoryDetail.IMagic__Order_Product__c = wrap.orderProduct;
                                inventoryDetailList_Insert.add(inventoryDetail);   
                                serialNumberListIndex++;
                            }
                        }
                    }
                    System.debug('here 9');
                    if(wrap.inventoryId != null && wrap.inventoryId != '' && Qty > 0){
                        inventory.IMagic__Quantity_on_Hand__c += Qty;
                        invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
                        invTransactionMap.put(wrap.inventoryId,invTransaction);
                        if(wrap.isSerialControlProduct){
                            for(Integer i = 0;i < Qty;i++){
                                IMagic__Inventory_Detail__c inventoryDetail = new IMagic__Inventory_Detail__c();
                                inventoryDetail.IMagic__Inventory__c = wrap.inventoryId;
                                inventoryDetail.Name = wrap.serialNumberList[serialNumberListIndex].serialNumber;
                                inventoryDetail.IMagic__Serial_Number__c = wrap.serialNumberList[serialNumberListIndex].serialNumber;
                                inventoryDetail.IMagic__Quantity__c = 1;    
                                inventoryDetailList_Insert.add(inventoryDetail);   
                                serialNumberListIndex++;
                            }
                        }
                    }
                    // inventoryList_Update.add(inventory);
                    if(wrap.inventoryId != null && wrap.inventoryId != ''){
                        inventoryMap.put(wrap.inventoryId,inventory);
                    }
    
    
                    IMagic__Receiving__c recieving = new IMagic__Receiving__c();
                    recieving.IMagic__Purchase_Order__c  = purchaseOrderId;
                    recieving.IMagic__Purchase_Order_Line__c = wrap.Id;
                    recieving.IMagic__Receiving_Date__c = Date.today();
                    recieving.IMagic__Received_By__c = UserInfo.getUserId();
                    recieving.IMagic__Status__c = wrap.quantityOrdered == (wrap.recievedQuantity + wrap.newQuantity) ? 'Received' : 'Partially Received';
                    recievingList_Insert.add(recieving);
                }
            }
            System.debug('inventoryMap after :: '+inventoryMap);
            if(inventoryMap != null){
                inventoryList_Update = inventoryMap.values();
            }

            System.debug('POLines_Update :: '+POLines_Update);
            System.debug('POLines_Update.Size :: '+POLines_Update.size());
    
            
            System.debug('recievingList_Insert :: '+recievingList_Insert);
            System.debug('recievingList_Insert.Size :: '+recievingList_Insert.size());
    
            
            System.debug('orderItemList_Update :: '+orderItemList_Update);
            System.debug('orderItemList_Update.Size :: '+orderItemList_Update.size());
    
            
            System.debug('inventoryList_Update :: '+inventoryList_Update);
            System.debug('inventoryList_Update.Size :: '+inventoryList_Update.size());
    
            
            System.debug('inventoryDetailList_Insert :: '+inventoryDetailList_Insert);
            System.debug('inventoryDetailList_Insert.Size :: '+inventoryDetailList_Insert.size());
            
            System.debug('purchaseOrderLineDetailList_Insert :: '+purchaseOrderLineDetailList_Insert);
            System.debug('purchaseOrderLineDetailList_Insert.Size :: '+purchaseOrderLineDetailList_Insert.size());


            if(!POLines_Update.isEmpty()){
                update POLines_Update;
            }
            if(!recievingList_Insert.isEmpty()){
                insert recievingList_Insert;
            }
            if(!orderItemList_Update.isEmpty()){
                update orderItemList_Update;
            } 
            if(!inventoryList_Update.isEmpty()){
                update inventoryList_Update;
            }
            // if(!inventoryDetailList_Insert.isEmpty()){
            //     insert inventoryDetailList_Insert;
            // }

            if(!purchaseOrderLineDetailList_Insert.isEmpty()){
                insert purchaseOrderLineDetailList_Insert;
            }

            System.debug('creating invTransactionMap :: '+invTransactionMap);
            if(invTransactionMap != null){
                insert invTransactionMap.values();
                System.debug('invTransactionMap inserted');
            }

            System.debug('creating inventoryDetailList_Insert :: '+inventoryDetailList_Insert);
            if(!inventoryDetailList_Insert.isEmpty()){
                for(IMagic__Inventory_Detail__c detail : inventoryDetailList_Insert){
                    if(invTransactionMap != null){
                        detail.IMagic__Inventory_Transaction__c = invTransactionMap.get(detail.IMagic__Inventory__c).Id;
                        
                    }
                }
                insert inventoryDetailList_Insert;
                System.debug('inventoryDetailList_Insert insert');
            }


            Lodestone__Purchase_Order__c  relatedPurchaseOrder = getPurchaseOrder(purchaseOrderId);

            System.debug('relatedPurchaseOrder :: '+relatedPurchaseOrder);
            if(relatedPurchaseOrder != null && relatedPurchaseOrder.RecordType.Name == 'Dropship PO'){
                IMagic__Shipment__c shipment = createShipment(relatedPurchaseOrder);
                System.debug('Created shiment '+ shipment);
                if(shipment != null){
                    createShipmentLine(orderLineWrapperList,shipment);
                    System.debug('Created shiment line');
                }
            }
            
            return purchaseOrderId;
        } 
        catch (AuraHandledException e) {
            System.debug('Qty Error '+e.getMessage());
            throw e;
        }catch (Exception ex) {
            System.debug(' Error While Update PO '+ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public static Lodestone__Purchase_Order__c  getPurchaseOrder(String purchaseOrderId){
        return [SELECT Id,Lodestone__Order__c,Lodestone__Account__c,Name,RecordType.Name FROM Lodestone__Purchase_Order__c  WHERE Id =: purchaseOrderId];
    }

    public static Shipment__c createShipment(Lodestone__Purchase_Order__c  po){
       try {
            IMagic__Shipment__c shipment = new IMagic__Shipment__c();
            shipment.IMagic__Account__c = po.Lodestone__Account__c;
            shipment.IMagic__Sales_Order__c = po.Lodestone__Order__c;
            shipment.IMagic__Shipment_Date__c = Date.today();
            shipment.IMagic__Tracking_Number__c	 = po.Name;
            insert shipment;
            return shipment;
      } catch (Exception e) {
            throw new AuraHandledException('Error Creating Shipment ' + e.getMessage());
        }
    }

    public static void createShipmentLine(List<purchaseOrderLineWrapper> purchaseOrderLine,Shipment__c shipment){
        try {
            List<IMagic__Shipment_Line__c> shipmentLine_Insert = new List<IMagic__Shipment_Line__c>();
            for(purchaseOrderLineWrapper wrapper : purchaseOrderLine){
                IMagic__Shipment_Line__c shipmentLine = new IMagic__Shipment_Line__c();
                shipmentLine.IMagic__Product__c = wrapper.productId;
                shipmentLine.IMagic__Quantity__c = wrapper.newQuantity;
                shipmentLine.IMagic__Shipments__c = shipment.Id;
                shipmentLine.IMagic__Unit_Price__c	 = wrapper.unitPrice;
                shipmentLine.IMagic__Order_Product__c = wrapper.orderProduct;
                shipmentLine_Insert.add(shipmentLine);
            }

            if(!shipmentLine_Insert.isEmpty()){
                insert shipmentLine_Insert;
            }
            System.debug('shipmentLine_Insert :: '+shipmentLine_Insert);
        } catch (Exception e) {
            throw new AuraHandledException('Error Creating Shipment Line ' + e.getMessage());
        }
    }

    public class purchaseOrderLineWrapper{
        @AuraEnabled public String Id {get; set;}
        @AuraEnabled public Decimal quantityOrdered {get; set;}
        @AuraEnabled public Decimal recievedQuantity {get; set;}
        @AuraEnabled public Decimal newQuantity {get; set;}
        @AuraEnabled public Decimal unitPrice {get; set;}
        @AuraEnabled public String productId {get; set;}
        @AuraEnabled public String productName {get; set;}
        @AuraEnabled public Decimal productCost {get; set;}
        @AuraEnabled public String productDescription {get; set;}
        @AuraEnabled public String productRecordTypeName {get; set;}
        @AuraEnabled public Boolean isSerialControlProduct {get; set;}
        @AuraEnabled public List<serialNumberWrapper> serialNumberList {get; set;}
        @AuraEnabled public String inventoryId {get; set;}
        @AuraEnabled public Decimal inventoryCost {get; set;}
        @AuraEnabled public String orderProduct {get; set;}
        @AuraEnabled public String stockingLocation {get; set;}
        @AuraEnabled public String purchaseOrderRecordTypeName {get; set;}
        @AuraEnabled public Boolean calculateAveragePriceForInv {get; set;}
    }

    public class serialNumberWrapper{
        @AuraEnabled public String purchaseOrderLineId {get; set;}
        @AuraEnabled public String serialNumber {get; set;}
    }
}