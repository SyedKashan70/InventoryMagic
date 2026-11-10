public with sharing class createInvoice_LineItemHandler {
    @InvocableMethod(Label='Create Invoice And Invoice Line' Description='Create Invoice And Invoice Line From Order' Category='Invocable Action')
    public static void createInvoice_InvoiceLine(List<Id> orderIds){
     try {
        System.debug('orderIds[0] : '+orderIds);
        Set<Id> productIds = new Set<Id>();
        Set<Id> stockingLocationIds = new Set<Id>();
        Map<String,Decimal> mapInvId_Qty = new Map<String,Decimal>();
        Set<Id> orderItemIds = new Set<Id>();
        List<IMagic__Inventory__c> inventoryList_Update = new List<IMagic__Inventory__c>();
        List<IMagic__Inventory_Detail__c> inventoryDetailList_Update = new List<IMagic__Inventory_Detail__c>();
        List<OrderItem> orderItemList_Update = new List<OrderItem>();
        // Map<Inv Id (Product Id + '::' + StockingLocationId),Transaction>
        Map<String,IMagic__Transaction_History__c> ProdId_locationId_InvTransactionMap = new Map<String,IMagic__Transaction_History__c>();
        Map<Id,Lodestone__Invoice_line__c> orderItemId_InvLineMap = new Map<Id,Lodestone__Invoice_line__c>();
        String orderId = orderIds[0];
        System.debug('orderId :: '+orderId);
        List<Order> order = [SELECT Id,AccountId,Account.IMagic__Terms__c,BillToContactId,BillingCity,BillingCountry,BillingStreet,ShippingCity,IMagic__Follow_Up_Frequency__c,IMagic__Stocking_Location__c,
                            ShippingCountry,ShippingStreet,(SELECT Id,Quantity,IMagic__Reserved_Quantity__c,IMagic__Shipped_Quantity__c,UnitPrice,Product2Id,Product2.Description,
                            Product2.RecordType.Name,IMagic__Stocking_Location__c FROM OrderItems WHERE 
                            IMagic__Reserved_Quantity__c > 0) FROM 
                            Order WHERE Id =: orderId LIMIT 1];
        
        Lodestone__Invoice__c invoice = createInvoiceRecord(order[0]);
        System.debug('invoice :: '+invoice);
        List<Lodestone__Invoice_line__c> invoiceLines = createInvoiceLineRecord(order[0].OrderItems,invoice);
        System.debug('invoiceLines :: '+invoiceLines);

        for(Lodestone__Invoice_line__c inv : invoiceLines){
            orderItemId_InvLineMap.put(inv.Lodestone__Order_Product__c,inv);
        }


        for(OrderItem oi : order[0].OrderItems){
            productIds.add(oi.Product2Id);
            stockingLocationIds.add(order[0].IMagic__Stocking_Location__c);
            orderItemIds.add(oi.Id);
            String key = oi.Product2Id + '::' + order[0].IMagic__Stocking_Location__c;
            Decimal orderedQty = oi.IMagic__Reserved_Quantity__c ;
            Decimal alreadyShippedQty = oi.IMagic__Shipped_Quantity__c != null ? oi.IMagic__Shipped_Quantity__c : 0;
            Decimal newShippingQty = orderedQty - alreadyShippedQty;

            IMagic__Transaction_History__c invTransaction = new IMagic__Transaction_History__c();
            invTransaction.IMagic__Type__c = 'Invoice Creation';
            invTransaction.IMagic__Transaction_Date_Time__c = Datetime.now();
            invTransaction.IMagic__Source_Stocking_Location__c = oi.IMagic__Stocking_Location__c;
            invTransaction.IMagic__Product__c = oi.Product2Id;
            invTransaction.IMagic__Order_Product__c = oi.Id;
            invTransaction.IMagic__Old_Reserved_Quantity__c = oi.IMagic__Reserved_Quantity__c;
            invTransaction.IMagic__New_Reserved_Quantity__c = oi.IMagic__Reserved_Quantity__c;
            invTransaction.IMagic__Quantity__c = oi.Quantity;
            invTransaction.IMagic__Invoice_Line_Item__c = orderItemId_InvLineMap.get(oi.Id).Id;
            ProdId_locationId_InvTransactionMap.put(key,invTransaction);

            // if(oi.Shipped_Quantity__c == 0){
                OrderItem oi_Update = new OrderItem();
                oi_Update.Id = oi.Id;
                // Decimal qty = oi_Update.Shipped_Quantity__c != null ? oi_Update.Shipped_Quantity__c : 0;
                oi_Update.IMagic__Shipped_Quantity__c = (newShippingQty + alreadyShippedQty);
                orderItemList_Update.add(oi_Update);
            // }

            
            if(mapInvId_Qty.containsKey(key)){
                orderedQty += mapInvId_Qty.get(key);
            }
            mapInvId_Qty.put(key,orderedQty);
        }

        List<IMagic__Inventory__c> relatedInventory = getRelatedInventory(productIds,stockingLocationIds,orderItemIds);

        for(IMagic__Inventory__c inventory : relatedInventory){
            String key = inventory.IMagic__Product__c + '::' + inventory.IMagic__Stocking_Location__c;
            Decimal inventoryReservedQty = inventory.IMagic__Quantity_Reserved__c != null ? inventory.IMagic__Quantity_Reserved__c : 0;
            Decimal orderItemQty = mapInvId_Qty.get(key) != null ? mapInvId_Qty.get(key) : 0;
            if(inventoryReservedQty < orderItemQty){
                throw new AuraHandledException('Order Product Quantity is Greater than Inventory Quantity');
            }

            IMagic__Transaction_History__c invTransaction = ProdId_locationId_InvTransactionMap.get(key);
            invTransaction.IMagic__Old_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
            invTransaction.IMagic__Old_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
            invTransaction.IMagic__Inventory__c = inventory.Id;

            inventory.IMagic__Quantity_Reserved__c = inventoryReservedQty - orderItemQty;
            inventoryList_Update.add(inventory);

            invTransaction.IMagic__New_Inventory_Quantity_Reserved__c = inventory.IMagic__Quantity_Reserved__c;
            invTransaction.IMagic__New_Inventory_Quantity_On_Hand__c = inventory.IMagic__Quantity_on_Hand__c;
            ProdId_locationId_InvTransactionMap.put(key,invTransaction);

            if(inventory.IMagic__Product__r.RecordType.Name == 'Serial Control'){
                for(IMagic__Inventory_Detail__c detail : inventory.IMagic__Inventory_Details__r){
                    detail.IMagic__Quantity_on_order__c = 0;
                    inventoryDetailList_Update.add(detail);
                }
            }
        }

        if(!inventoryList_Update.isEmpty()){
            update inventoryList_Update;
        }

        if(ProdId_locationId_InvTransactionMap != null){
            insert ProdId_locationId_InvTransactionMap.values();
        }

        if(!inventoryDetailList_Update.isEmpty()){
            for(IMagic__Inventory_Detail__c detail : inventoryDetailList_Update){
                String key = detail.IMagic__Inventory__r.IMagic__Product__c + '::' + detail.IMagic__Inventory__r.IMagic__Stocking_Location__c;
                if(ProdId_locationId_InvTransactionMap != null){
                    detail.IMagic__Inventory_Transaction__c = ProdId_locationId_InvTransactionMap.get(key).Id;
                    
                }
            }
            update inventoryDetailList_Update;
        }

        if(!orderItemList_Update.isEmpty()){
            update orderItemList_Update;
        }

        Order order_update = new Order();
        order_update.Id = orderId;
        order_update.IMagic__Invoiced__c = true;
        order_update.Status = 'Invoiced';
        update order_update;

        Task task = createTask(order[0]);

     } catch (Exception ex) {
        System.debug('Invoice Creation Failed :: '+ex.getMessage());
        throw new AuraHandledException('Invoice Creation Failed :: '+ex.getMessage());
     }
    }

    public static Integer getDueDateDays(String paymentTerm) {
        // Check if the input is not null and contains "Net"
        if (paymentTerm != null && paymentTerm.contains('Net')) {
            // Use regular expression to find "Net" followed by digits
            Pattern netPattern = Pattern.compile('Net (\\d+)');
            Matcher matcher = netPattern.matcher(paymentTerm);

            if (matcher.find()) {
                // Return the first matching group as an Integer
                return Integer.valueOf(matcher.group(1));
            }
        }
        // Return null if no "Net" term is found
        return null;
    }

    public static Lodestone__Invoice__c createInvoiceRecord(Order order){
        Integer days = getDueDateDays(order.Account.Terms__c) != null ? getDueDateDays(order.Account.Terms__c) : 0;
        Lodestone__Invoice__c inv = new Lodestone__Invoice__c();
        if(order != null){
            inv.Lodestone__Account__c = order.AccountId;
            inv.Lodestone__Order__c = order.Id;
            inv.Lodestone__Contact__c = order.BillToContactId;
            inv.IMagic__Billing_City__c = order.BillingCity;
            inv.IMagic__Billing_Country__c = order.BillingCountry;
            inv.IMagic__Billing_Street__c = order.BillingStreet;
            inv.IMagic__Shipping_City__c = order.ShippingCity;
            inv.IMagic__Shipping_Country__c = order.ShippingCountry;
            inv.IMagic__Shipping_Street__c = order.ShippingStreet;
            inv.Lodestone__Invoice_Date__c = Date.today();
            inv.Lodestone__Due_Date__c = Date.today().addDays(days);
        }   
        insert inv;
        return inv;                          
    }

    public static List<Lodestone__Invoice_line__c> createInvoiceLineRecord(List<OrderItem> orderItemList,Lodestone__Invoice__c invoice){
        List<Lodestone__Invoice_line__c> invLine_Insert = new List<Lodestone__Invoice_line__c>(); 
        if(!orderItemList.isEmpty()){
            for(OrderItem oi : orderItemList){
                Lodestone__Invoice_line__c invLine = new Lodestone__Invoice_line__c();
                invLine.Lodestone__Invoice__c = invoice.Id;
                invLine.Lodestone__Order_Product__c = oi.Id;
                invLine.Lodestone__Quantity__c = oi.IMagic__Reserved_Quantity__c;
                invLine.Lodestone__Unit_Price__c = oi.UnitPrice;
                invLine.Lodestone__Product__c = oi.Product2Id;
                invLine.Lodestone__Product_Description__c = oi.Product2.Description;
                invLine_Insert.add(invLine);
            }
        }   
        insert invLine_Insert;
        return invLine_Insert;                          
    }

    public static List<IMagic__Inventory__c> getRelatedInventory(Set<Id> proIds,Set<Id> stockingLocationIds,Set<Id> orderItemIds){
        System.debug('proIds :: '+proIds);
        System.debug('stockingLocationIds :: '+stockingLocationIds);
        System.debug('orderItemIds :: '+orderItemIds);
        Set<String> inventoryDetailSet = new Set<String>();
        System.debug('inventoryDetailSet :: '+inventoryDetailSet);
        List<IMagic__Inventory__c> inventoryList = [SELECT Id,IMagic__Product__c,IMagic__Stocking_Location__c,IMagic__Quantity_Reserved__c,IMagic__Quantity_on_Hand__c,
                                            IMagic__Product__r.RecordType.Name, (SELECT Id,Name,IMagic__Quantity_on_order__c,IMagic__Quantity__c,IMagic__Inventory__c,
                                            IMagic__Inventory__r.IMagic__Product__c,IMagic__Inventory__r.IMagic__Stocking_Location__c 
                                            FROM IMagic__Inventory_Details__r WHERE IMagic__Order_Product__c IN: orderItemIds) FROM IMagic__Inventory__c 
                                            WHERE IMagic__Product__c IN: proIds AND IMagic__Stocking_Location__c IN: stockingLocationIds AND IMagic__Quantity_Reserved__c > 0];
        return inventoryList;
    }

    public static Task createTask(Order order){
        Date taskDate = Date.today();
        if(order.IMagic__Follow_Up_Frequency__c != null){
            if(order.IMagic__Follow_Up_Frequency__c == 'Yearly'){
                taskDate = taskDate.addYears(1);
            }
            else if(order.IMagic__Follow_Up_Frequency__c == 'Monthly'){
                taskDate = taskDate.addMonths(1);
            }
            else{
                taskDate = taskDate.addMonths(3);
            }
        }
        else{
            taskDate = taskDate.addMonths(3);
        }
        Task task = new Task();
        task.Subject = 'Follow Up Order Task';
        task.WhatId = order.Id;
        task.OwnerId = UserInfo.getUserId();
        task.ActivityDate = taskDate;
        task.Priority = 'High';
        task.Type = 'Call';
        task.Status = 'Open';
        
        insert task;
        return task;
    }

    
}