@isTest
public with sharing class createInvoice_LineItemHandlerTest {
    @TestSetup
    static void makeData(){
        //Creating Account
        Account account = D_TestDataFactory.createAccount('Test Account Family', false);
        // account.Payment_Terms__c = 'Net 10';
        insert account;

        //Creating Contact
        Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);

        //Creating Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', true);

        //Creating Standard PBE for Product
        PricebookEntry pbe = D_TestDataFactory.createPriceBookEntry(Test.getStandardPricebookId(),product.Id,true);

        //Creating Warehouse
        IMagic__Warehouse__c Warehouse = D_TestDataFactory.createWareHouse('Warehouse',true);

        //Creating Stocking Location
        IMagic__Stocking_Location__c StockingLocation = D_TestDataFactory.createStockingLocation('Stocking Location',Warehouse.Id,true);

        //Creating Stocking Location
        IMagic__Stocking_Location__c mainStockingLocation = D_TestDataFactory.createStockingLocation('Stocking Location',Warehouse.Id,false);
        mainStockingLocation.IMagic__is_Main_Stocking_Location__c = true;
        insert mainStockingLocation;

        //Creating Order
        Order order = D_TestDataFactory.createOrder(account.Id, contact.Id, false);
        order.IMagic__Stocking_Location__c = StockingLocation.Id;
        order.IMagic__Warehouse__c = Warehouse.Id;
        order.Status = 'Open';
        insert order;   

        //Creating OrderItem
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem.IMagic__Stocking_Location__c = StockingLocation.Id;
        insert orderItem;  
        
        //Creating Inventory
        IMagic__Inventory__c Inventory = D_TestDataFactory.createInventory('Inventory',StockingLocation.Id,product.Id,true);

        //Creating Inventory Detail
        IMagic__Inventory_Detail__c createInventoryDetail = D_TestDataFactory.createInventoryDetail(Inventory.Id,orderItem.Id,true);  
    }

    
    @isTest
    static void testcreateInvoice_InvoiceLine() {
        // Retrieve test Order Id from Test Setup data
        List<Id> orderIds = new List<Id>();
        for(Order ord : [SELECT Id FROM Order]){
            orderIds.add(ord.Id);
        }

        Test.startTest();
        createInvoice_LineItemHandler.createInvoice_InvoiceLine(orderIds);
        Test.stopTest();

        Assert.isNotNull(orderIds,'Order Ids should not be null');
        Assert.isTrue(!orderIds.isEmpty(),'Order Ids should not be empty'); 

    }
}