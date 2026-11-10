/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
public with sharing class offlineController {

    @AuraEnabled
    public static List<Account> getCustomerAccounts() {
        return [Select Id,Name FROM Account Where RecordType.Name = 'Customer'];
    }

    @AuraEnabled
    public static List<Product2Wrapper> getActiveProducts() {
        List<IMagic__Stocking_Location__c> userStockingLocations = getUserStockingLocation();
        if(userStockingLocations.isEmpty()){
            throw new AuraHandledException('You do not have access to any stocking location');
        }
        System.debug('userStockingLocations :: '+userStockingLocations);

        Set<Id> setOfProdIds = new Set<Id>();
        List<Product2> productList = [SELECT Id, Name, IsActive,Description,Lodestone__Sale_Price__c FROM Product2 WHERE IsActive = true];
        for(Product2 pro : productList){
            setOfProdIds.add(pro.Id);
        }
        System.debug('setOfProdIds :: '+setOfProdIds);

        Map<String,IMagic__Inventory__c> mapOfInventory = getRelatedInventory(setOfProdIds,userStockingLocations[0].Id);
        List<Product2Wrapper> product2WrapperList = new List<Product2Wrapper>();
        for(Product2 pro : productList){
            String key = pro.Id + '::' + userStockingLocations[0].Id;
            Product2Wrapper wrap = new Product2Wrapper();
            wrap.Id = pro.Id;
            wrap.Name = pro.Name;   
            wrap.Description = pro.Description;
            wrap.IsActive = pro.IsActive;
            wrap.salesPrice = pro.Lodestone__Sale_Price__c;
            wrap.invId = mapOfInventory.get(key) != null ? mapOfInventory.get(key).Id : null;   
            product2WrapperList.add(wrap);
        }
        return product2WrapperList;
    }

    @AuraEnabled
    public static List<IMagic__Stocking_Location__c> getStockingLocations() {
        try {
            // Query the main warehouse stocking location based on the logged-in user
            List<IMagic__Stocking_Location__c> stockingLocations = [
                SELECT Id, Name,IMagic__Warehouse__c FROM IMagic__Stocking_Location__c WHERE IMagic__is_Main_Stocking_Location__c = false];
            
            return stockingLocations;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get getStockingLocation :: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static List<IMagic__Warehouse__c> getWareHouses() {
        try {
            // Query the main warehouse stocking location based on the logged-in user
            List<IMagic__Warehouse__c> warehouses = [
                SELECT Id, Name,IMagic__Warehouse_Manager__r.Email FROM IMagic__Warehouse__c];
            
            return warehouses;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get getwarehouses :: ' + ex.getMessage());
        }
    }
    
    
    public static Order createStandardOrder(String accId, Pricebook2 standardPriceBook,Date orderStartDate,String warehouseId,String stockingLocationId){
        Order standardOrder = new Order();
        standardOrder.AccountId = accId;
        standardOrder.Status = 'Open';
        standardOrder.EffectiveDate = orderStartDate;
        standardOrder.Warehouse__c = warehouseId;
        standardOrder.Stocking_Location__c = stockingLocationId;
        standardOrder.Pricebook2Id = standardPriceBook.Id;
        return standardOrder;
    }
    
    @AuraEnabled
    public static String createOrderandOrderProduct(List<orderWrapper> cachedOrders){
        SavePoint sp = Database.setSavepoint();
        try {
            System.debug('cachedOrders :: '+cachedOrders);
            Set<Id> allProductIds = new Set<Id>();
            Map<Id, PricebookEntry> priceBookEntryMap = new Map<Id, PricebookEntry>();
            Map<String,Order> orderMap = new Map<String,Order>();
            List<OrderItem> orderItem_Insert = new List<OrderItem>();

            // Fetch the Standard Pricebook
            Pricebook2 standardPriceBook = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];

            for (orderWrapper wrap : cachedOrders) {
                for (productWrapper pw : wrap.products) {
                    allProductIds.add(pw.productId);
                }
            }

            // Query all the PricebookEntries for the standard Pricebook
            List<PricebookEntry> pricebookEntries = [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :standardPriceBook.Id AND Product2Id IN :allProductIds];

            // Populate the Map with the Product2Id as the key
            for (PricebookEntry entry : pricebookEntries) {
                priceBookEntryMap.put(entry.Product2Id, entry);
            }

            
            for (orderWrapper wrap : cachedOrders) {
                String key = wrap.id + '::' + wrap.accountId;
                Order standardOrder = createStandardOrder(wrap.accountId, standardPriceBook,wrap.orderStartDate,wrap.warehouseId,wrap.stockingLocationId);
                orderMap.put(key,standardOrder);
            }
          
            List<Order> orderList = orderMap.values();
            if(!orderList.isEmpty()){
                insert orderList;
            }    

            for (orderWrapper wrap : cachedOrders) {
                String key = wrap.id + '::' + wrap.accountId;
                for (productWrapper pw : wrap.products) {
                    OrderItem item = new OrderItem();
                    item.OrderId  = orderMap.get(key).Id;
                    item.Product2Id = pw.productId;
                    item.UnitPrice = pw.cost;
                    item.Quantity = pw.quantity;
                    item.PricebookEntryId = priceBookEntryMap.get(pw.productId).Id;
                    item.Description = pw.lineDescription;
                    orderItem_Insert.add(item);
                }
            }
            System.debug('orderItem_Insert :: '+orderItem_Insert);

            if(!orderItem_Insert.isEmpty()){
                insert orderItem_Insert;
            }

            List<String> toAddressList = new List<String>();
            for (orderWrapper wrap : cachedOrders) {
                toAddressList.add(wrap.warehouseManagerEmail);
            }

            sendEmail('New Orders Created', 'Dear Manager, few more Offline orders are Created.', toAddressList);

            System.debug('orderItem_Insert after :: '+orderItem_Insert);
            return 'Offline Orders Sync Successfully!.';
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('e.getMessage() ::  '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void sendEmail(String subject, String body, List<String> toAddresses) {
        
        // Create a SingleEmailMessage instance
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);
        email.setSubject(subject);
        email.setHtmlBody(body);  
        
        // Send the email
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        // Check the result for success
        if (results != null && results.size() > 0 && results[0].isSuccess()) {
            System.debug('Email sent successfully with attachment.');
        } else {
            System.debug('Failed to send email with attachment: ' + results[0].getErrors());
        }
    }

     // Method to create Opportunity
     public static Opportunity createOpportunity(String accName, String accId, Pricebook2 standardPriceBook){
        Opportunity opp = new Opportunity();
        opp.Name = accName + ' Opportunity';
        opp.StageName = 'Prospecting';
        opp.CloseDate = System.today();
        opp.Pricebook2Id = standardPriceBook.Id; 
        opp.AccountId = accId;
        return opp;
    }

    // Method to create Opportunity Line Items
    public static List<OpportunityLineItem> createOpportunityLines(List<quoteProductWrapper> ProductWrapperList, Id OpportunityId, Map<Id, PricebookEntry> priceBookEntryMap){
        List<OpportunityLineItem> oppProduct_Insert = new List<OpportunityLineItem>();
        for(quoteProductWrapper wrap : ProductWrapperList){
            System.debug('wrap :: '+wrap);
            PricebookEntry priceBookEntry = priceBookEntryMap.get(wrap.productId);
            OpportunityLineItem oppProduct = new OpportunityLineItem();
            oppProduct.OpportunityId = OpportunityId;
            oppProduct.UnitPrice = wrap.unitPrice != null ? wrap.unitPrice : 0;
            oppProduct.Quantity = wrap.quantity;
            System.debug('here');
            System.debug('priceBookEntry.Id; :: '+priceBookEntry);
            oppProduct.PricebookEntryId = priceBookEntry.Id; 
            System.debug('here');
            oppProduct_Insert.add(oppProduct);
        }
        return oppProduct_Insert;
    }

    // Method to create Quote
    public static Quote createQuoteForOpportunity(Id OpportunityId, String accName,Id stockingLocationId){
        Quote quote = new Quote();
        quote.OpportunityId = OpportunityId;
        quote.Name = accName + ' Quote';
        quote.IMagic__Stocking_Location__c = stockingLocationId;
        return quote;
    }

    // Method to create Quote Line Items for a Quote
    public static List<QuoteLineItem> createQuoteLineItems(List<quoteProductWrapper> ProductWrapperList, Id QuoteId, Map<Id, PricebookEntry> priceBookEntryMap,String locationId){
        List<QuoteLineItem> quoteLineItem_Insert = new List<QuoteLineItem>();
        for(quoteProductWrapper wrap : ProductWrapperList){
            PricebookEntry priceBookEntry = priceBookEntryMap.get(wrap.productId);
            QuoteLineItem quoteLineItem = new QuoteLineItem();
            quoteLineItem.QuoteId = QuoteId;
            quoteLineItem.UnitPrice = wrap.unitPrice != null ? wrap.unitPrice : 0;
            quoteLineItem.Quantity = wrap.quantity;
            quoteLineItem.PricebookEntryId = priceBookEntry.Id;
            quoteLineItem.Description = wrap.description;
            quoteLineItem_Insert.add(quoteLineItem);
        }

        return quoteLineItem_Insert;
    }


    @AuraEnabled
    public static String createQuoteandQuoteLines(List<quoteWrapper> cachedQuotes){
        SavePoint sp = Database.setSavepoint();
        try {
            System.debug('quoteData :: '+cachedQuotes);
            Set<Id> allProductIds = new Set<Id>();
            Map<Id, PricebookEntry> priceBookEntryMap = new Map<Id, PricebookEntry>();
            Map<String,Opportunity> oppMap = new Map<String,Opportunity>();
            Map<String,Quote> quoteMap = new Map<String,Quote>();

            // Fetch the Standard Pricebook
            Pricebook2 standardPriceBook = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1];

            for (quoteWrapper wrap : cachedQuotes) {
                for (quoteProductWrapper pw : wrap.products) {
                    allProductIds.add(pw.productId);
                }
            }

            // Query all the PricebookEntries for the standard Pricebook
            List<PricebookEntry> pricebookEntries = [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :standardPriceBook.Id AND Product2Id IN :allProductIds];

            // Populate the Map with the Product2Id as the key
            for (PricebookEntry entry : pricebookEntries) {
                priceBookEntryMap.put(entry.Product2Id, entry);
            }

            for(quoteWrapper wrap : cachedQuotes){
                String key = wrap.id + '::' + wrap.accountId;
                // Create Opportunity
                Opportunity opp = createOpportunity(wrap.accountName, wrap.accountId, standardPriceBook);
                oppMap.put(key,opp);
            }

            List<Opportunity> oppList = oppMap.values();
            if(!oppList.isEmpty()){
                insert oppList;
            }

            System.debug('oppList :: '+oppList);
            List<OpportunityLineItem> oppLineItem = new List<OpportunityLineItem>();
            for(quoteWrapper wrap : cachedQuotes){
                String key = wrap.id + '::' + wrap.accountId;
                // Create Opportunity Line Items
                oppLineItem.addAll(createOpportunityLines(wrap.products, oppMap.get(key).Id, priceBookEntryMap));
                System.debug('oppLineItem :: '+oppLineItem);
                //Quote
                Quote quote = createQuoteForOpportunity(oppMap.get(key).Id, wrap.accountName,wrap.locationId);
                quoteMap.put(key,quote);
            }

            if(!oppLineItem.isEmpty()){
                insert oppLineItem;
            }

            List<Quote> quoteList = quoteMap.values();
            if(!quoteList.isEmpty()){
                insert quoteList;
            }

            List<QuoteLineItem> qlis = new List<QuoteLineItem>();
            for(quoteWrapper wrap : cachedQuotes){
                String key = wrap.id + '::' + wrap.accountId;
                // Create Quote Line Items for the Quote
                qlis.addAll(createQuoteLineItems(wrap.products, quoteMap.get(key).Id, priceBookEntryMap,wrap.locationId));
            }

            System.debug('quoteList :: '+quoteList);

            if(!qlis.isEmpty()){
                insert qlis;
            }
            System.debug('qlis :: '+qlis);

            
            return 'Offline Quotes Sync Successfully!.';
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('e.getMessage() ::  '+e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }



    
    public static List<IMagic__Stocking_Location__c> getUserStockingLocation() {
        // Get the logged-in user ID
        Id loggedInUserId = UserInfo.getUserId();
        System.debug('loggedInUserId :: '+loggedInUserId);
        try {
            // Query the main warehouse stocking location based on the logged-in user
            List<IMagic__Stocking_Location__c> mainWarehouseStock = [
                SELECT Id, Name, IMagic__Warehouse__c, IMagic__Warehouse__r.Name
                FROM IMagic__Stocking_Location__c 
                WHERE IMagic__Sales_Rep__c = :loggedInUserId
                LIMIT 1
            ];
            
            return mainWarehouseStock;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to get getMainWarehouseStockingLocation :: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static List<serialListWrapper> getInventoryDetailList(List<Id> invIds) {
        System.debug('invIds :: '+invIds);
        List<IMagic__Inventory_Detail__c> details = [
            SELECT Id, Name, IMagic__Inventory__c ,IMagic__Quantity__c
            FROM IMagic__Inventory_Detail__c 
            WHERE IMagic__Inventory__c IN :invIds AND Quantity__c > 0
        ];
        
        System.debug('details :: '+details);
        List<serialListWrapper> wrapperList = new List<serialListWrapper>();
        
        for (Inventory_Detail__c detail : details) {
            serialListWrapper wrap = new serialListWrapper();
            wrap.Id = detail.Id;
            wrap.Name = detail.Name;
            wrap.inventoryId = detail.IMagic__Inventory__c;
            wrap.isOrdered = false;
            wrapperList.add(wrap);
        }

        return wrapperList;
    }
    
    @AuraEnabled
    public static List<OrderLineWrapper> getOrderItemsToReserve(){
        try {
            List<IMagic__Stocking_Location__c> userStockingLocations = getUserStockingLocation();
            if(userStockingLocations.isEmpty()){
                throw new AuraHandledException('You do not have access to any stocking location');
            }
            System.debug('userStockingLocations :: '+userStockingLocations);
            Set<Id> setOfProdIds = new Set<Id>();
            // Set<Id> setOfStockLocIds = new Set<Id>();
            List<OrderLineWrapper> orderLineWrapperList = new List<OrderLineWrapper>();
            List<OrderItem> orderItemList = [SELECT Id, OrderId,Order.OrderNumber,IMagic__Stocking_Location__c,Product2Id,Quantity,Product2.RecordType.Name,
                                            Product2.Lodestone__Supplier__c,Product2.Lodestone__Supplier__r.Name,Order.AccountId,Order.Account.Name,
                                            Product2.Name,IMagic__Stocking_Location__r.Name,IMagic__Reserved_Quantity__c,IMagic__PO_Quantity__c,IMagic__Remaining_QTY__c,UnitPrice
                                            FROM OrderItem WHERE Quantity > 0 AND IMagic__Remaining_QTY__c > 0  AND 
                                            Product2.Lodestone__Supplier__c != null AND 
                                            Order.IMagic__Stocking_Location__c =: userStockingLocations[0].Id
                                            AND (Order.Status = 'Open' OR Order.Status = 'InProgress')];

            for(OrderItem orditem : orderItemList){
                setOfProdIds.add(orditem.Product2Id);
                // setOfStockLocIds.add(orditem.IMagic__Stocking_Location__c);
            }     

            Map<String,IMagic__Inventory__c> mapOfInventory = getRelatedInventory(setOfProdIds,userStockingLocations[0].Id);
            System.debug('mapOfInventory :: '+mapOfInventory);
            for(OrderItem orditem : orderItemList){
                String key = orditem.Product2Id + '::' + userStockingLocations[0].Id;
                Decimal invQty = mapOfInventory.get(key) != null ? mapOfInventory.get(key).IMagic__Quantity_on_Hand__c : 0;
                System.debug('orditem.IMagic__Remaining_QTY__ :: '+orditem.IMagic__Remaining_QTY__c);
                System.debug('invQty :: '+invQty);
                if(invQty >= orditem.IMagic__Remaining_QTY__c){
                    OrderLineWrapper wrap = new OrderLineWrapper();
                    wrap.Id = orditem.Id;
                    wrap.orderId = orditem.OrderId;
                    wrap.orderNumber = orditem.Order.OrderNumber;
                    wrap.stockingLocationId = orditem.IMagic__Stocking_Location__c;
                    wrap.stockingLocationName = orditem.IMagic__Stocking_Location__r.Name;
                    wrap.unitPrice = orditem.UnitPrice != null ? orditem.UnitPrice : 0;
                    wrap.quantityOrdered = orditem.Quantity != null ? orditem.Quantity : 0;
                    wrap.quantityReserved = orditem.IMagic__Reserved_Quantity__c != null ? orditem.IMagic__Reserved_Quantity__c : 0;
                    wrap.quantityRemaining = orditem.IMagic__Remaining_QTY__c != null ? orditem.IMagic__Remaining_QTY__c : 0;
                    wrap.newQuantity = 0;
                    wrap.productId = orditem.Product2Id;
                    wrap.productName = orditem.Product2.Name;
                    wrap.productRecordTypeName = orditem.Product2.RecordType.Name;
                    wrap.isSerialControlProduct = orditem.Product2.RecordType.Name == 'Serial Control' ? true : false;
                    if(!String.isBlank(orditem.Product2?.Lodestone__Supplier__c)){     
                        wrap.supplierId = orditem.Product2?.Lodestone__Supplier__c != null ? orditem.Product2.Lodestone__Supplier__c : null;
                        wrap.supplierName = orditem.Product2?.Lodestone__Supplier__c != null ? orditem.Product2.Lodestone__Supplier__r.Name : null;
                    }
                    if(!String.isBlank(orditem.Order.AccountId)){     
                        wrap.orderAccountId = orditem.Order.AccountId != null ? orditem.Order.AccountId : null;
                        wrap.orderAccountName = orditem.Order.AccountId != null ? orditem.Order.Account.Name : null;
                    }
                    wrap.inventoryId = mapOfInventory.get(key) != null ? mapOfInventory.get(key).Id : null;               
                    wrap.inventoryAvailableQuantity = mapOfInventory.get(key) != null ? mapOfInventory.get(key).IMagic__Quantity_on_Hand__c : 0;
                    wrap.isSelected = false;
                    orderLineWrapperList.add(wrap);
                }
            }
            System.debug('orderLineWrapperList :: '+orderLineWrapperList);
            return orderLineWrapperList;
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Map<String,IMagic__Inventory__c> getRelatedInventory(Set<Id> proIds,Id stockingLocationId){
        System.debug('proIds :: '+proIds);
        Map<String, IMagic__Inventory__c> MapOfInv = new Map<String, IMagic__Inventory__c>();
        List<IMagic__Inventory__c> inventoryList = [SELECT Id,IMagic__Product__c,IMagic__Stocking_Location__c,IMagic__Quantity_Reserved__c,IMagic__Quantity_on_Hand__c,
                                            IMagic__Product__r.RecordType.Name,IMagic__Cost__c FROM IMagic__Inventory__c 
                                            WHERE IMagic__Product__c IN: proIds AND IMagic__Stocking_Location__c =: stockingLocationId];
        for(IMagic__Inventory__c inv : inventoryList){
            String key = inv.IMagic__Product__c + '::' + stockingLocationId;
            MapOfInv.put(key, inv);
        }
        return MapOfInv;
    }


    @AuraEnabled
    public static List<InvLineWrapper> getInventory() {
        try {
            List<IMagic__Stocking_Location__c> userStockingLocations = getUserStockingLocation();
            if(userStockingLocations.isEmpty()){
                throw new AuraHandledException('You do not have access to any stocking location');
            }
            List<InvLineWrapper> invLineWrapperList = new List<InvLineWrapper>();
            List<IMagic__Inventory__c> invItemList = [SELECT Id,IMagic__Product__c,IMagic__Quantity_on_Hand__c,IMagic__Cost__c,
                                                     IMagic__Quantity_Reserved__c FROM IMagic__Inventory__c WHERE 
                                                     IMagic__Quantity_on_Hand__c > 0 AND 
                                                     IMagic__Stocking_Location__c =: userStockingLocations[0].Id];
            System.debug('invItemList :: '+invItemList);

            for (Inventory__c item : invItemList) {
                    InvLineWrapper wrap = new InvLineWrapper();
                    wrap.Id = item.Id;
                    wrap.quantityOnHand = item.IMagic__Quantity_on_Hand__c != null ? item.IMagic__Quantity_on_Hand__c : 0;
                    wrap.quantityReserved = item.IMagic__Quantity_Reserved__c != null ? item.IMagic__Quantity_Reserved__c : 0;
                    wrap.cost = item.IMagic__Cost__c != null ? item.IMagic__Cost__c : 0;
                    wrap.productId = item.IMagic__Product__c;
                    invLineWrapperList.add(wrap);
            }
            System.debug('invLineWrapperList :: ' + invLineWrapperList);
            return invLineWrapperList;

        } 
        catch (AuraHandledException e) {
            throw e;
        }catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch Inventory items: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String reservedOrderProduct(List<OrderLineWrapper> OrderLines,List<InvLineWrapper> invLines){
        SavePoint sp = Database.setSavepoint();
       try {
        List<OrderItem> orderItemList = new List<OrderItem>();
        List<IMagic__Inventory__c> inventoryList = new List<IMagic__Inventory__c>();
        Map<Id,OrderLineWrapper> orderLineMap = new Map<Id,OrderLineWrapper>();
        List<Inventory_Detail__c> invDetailList_Update = new List<Inventory_Detail__c>();
        System.debug('OrderLines :: '+OrderLines);
        for(OrderLineWrapper wrap : OrderLines){
            System.debug('wrap :: '+wrap);
            if(wrap.quantityReserved > 0){
                OrderItem oi = new OrderItem();
                oi.Id = wrap.Id;
                oi.IMagic__Reserved_Quantity__c = wrap.quantityReserved;
                orderItemList.add(oi);
                orderLineMap.put(wrap.inventoryId,wrap);
                
                if(wrap.isSerialControlProduct){
                    for(serialListWrapper serial : wrap.serialList){
                        Inventory_Detail__c detail = new Inventory_Detail__c();
                        detail.Id = serial.Id;
                        detail.Order_Product__c = wrap.Id;
                        detail.Quantity__c = 0;
                        detail.Quantity_on_order__c = 1;
                        invDetailList_Update.add(detail);
                    }
                }
                
                
            }
        }

        // List<IMagic__Inventory__c> invItemList = [SELECT Id,IMagic__Product__c,IMagic__Quantity_on_Hand__c,IMagic__Cost__c,
        //                                              IMagic__Quantity_Reserved__c FROM IMagic__Inventory__c WHERE Id IN: orderLineMap.keySet()];

        // System.debug('invItemList :: '+invItemList);
        // for(IMagic__Inventory__c inv : invItemList){
        //     if(orderLineMap.containsKey(inv.Id)){
        //         OrderLineWrapper orderLine = orderLineMap.get(inv.Id);
        //         IMagic__Inventory__c invObj = new IMagic__Inventory__c();
        //         invObj.Id = inv.Id;
        //         invObj.IMagic__Quantity_Reserved__c = orderLine.quantityReserved;
        //         invObj.IMagic__Quantity_on_Hand__c = orderLine.inventoryAvailableQuantity;
        //         inventoryList.add(invObj);
        //     }
        // }

        for(InvLineWrapper inv : invLines){
                IMagic__Inventory__c invObj = new IMagic__Inventory__c();
                invObj.Id = inv.Id;
                invObj.IMagic__Quantity_Reserved__c = inv.quantityReserved;
                invObj.IMagic__Quantity_on_Hand__c = inv.quantityOnHand;
                inventoryList.add(invObj);
        }

        System.debug('inventoryList :: '+inventoryList);
        if(!inventoryList.isEmpty()){
            update inventoryList;
        }

        System.debug('orderItemList :: '+orderItemList);
        if(!orderItemList.isEmpty()){
            update orderItemList;
        }

        if(!invDetailList_Update.isEmpty()){
            update invDetailList_Update;
        }

        return 'Order Reserved Successfully!.';
       } catch (Exception ex) {
        Database.rollback(sp);
           throw new AuraHandledException('Failed to Reserved Order :: '+ex.getMessage());
       }
    }

    public class orderWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public Date orderStartDate { get; set; }
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String warehouseId { get; set; }
        @AuraEnabled public String warehouseName { get; set; }
        @AuraEnabled public String warehouseManagerEmail { get; set; }
        @AuraEnabled public String stockingLocationId { get; set; }
        @AuraEnabled public String stockingLocationName { get; set; }
        @AuraEnabled public List<productWrapper> products {get; set;}
    }

    public class productWrapper {
        @AuraEnabled public String rowNumber { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String lineDescription { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal cost { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
    }

    public class quoteWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String locationId { get; set; }
        @AuraEnabled public String locationName { get; set; }
        @AuraEnabled public List<quoteProductWrapper> products {get; set;}
    }

    public class quoteProductWrapper {
        @AuraEnabled public String rowNumber { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public String description { get; set; }
    }


    public class OrderLineWrapper{
        @AuraEnabled public String Id {get; set;}
        @AuraEnabled public String orderId {get; set;}
        @AuraEnabled public String orderNumber {get; set;}
        @AuraEnabled public String stockingLocationId {get; set;}
        @AuraEnabled public String stockingLocationName {get; set;}
        @AuraEnabled public Decimal unitPrice {get; set;}
        @AuraEnabled public Decimal quantityOrdered {get; set;}
        @AuraEnabled public Decimal quantityReserved {get; set;}
        @AuraEnabled public Decimal quantityRemaining {get; set;}
        @AuraEnabled public Decimal newQuantity {get; set;}
        @AuraEnabled public String productId {get; set;}
        @AuraEnabled public String productName {get; set;}
        @AuraEnabled public String productRecordTypeName {get; set;}
        @AuraEnabled public Boolean isSerialControlProduct {get; set;}
        @AuraEnabled public String supplierId {get; set;}
        @AuraEnabled public String supplierName {get; set;}
        @AuraEnabled public String orderAccountId {get; set;}
        @AuraEnabled public String orderAccountName {get; set;}
        @AuraEnabled public String inventoryId {get; set;}
        @AuraEnabled public Decimal inventoryAvailableQuantity {get; set;}
        @AuraEnabled public List<serialListWrapper> serialList {get; set;}
        @AuraEnabled public Boolean isSelected {get; set;}
    }

    
    public class serialListWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String inventoryId { get; set; }
        @AuraEnabled public Boolean isOrdered { get; set; }
    }

    public class Product2Wrapper{
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public Boolean IsActive { get; set; }
        @AuraEnabled public Decimal salesPrice { get; set; }
        @AuraEnabled public String Description { get; set; }
        @AuraEnabled public String invId { get; set; }
    }

    public class InvLineWrapper{
        @AuraEnabled public String Id {get; set;}
        @AuraEnabled public String productId {get; set;}
        @AuraEnabled public Decimal quantityOnHand {get; set;}
        @AuraEnabled public Decimal quantityReserved {get; set;}
        @AuraEnabled public Decimal cost {get; set;}
    }
}