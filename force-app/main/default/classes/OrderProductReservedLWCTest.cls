@isTest
public with sharing class OrderProductReservedLWCTest {
    @TestSetup
    static void makeData(){
        //Creating Account
        Account account = D_TestDataFactory.createAccount('Test Account Family', true);

        //Creating Contact
        Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);

        //Creating Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false); //Inventory don't exist
        product.RecordTypeId =  Schema.SObjectType.Product2.getRecordTypeInfosByName().get('Non Serial Control').getRecordTypeId();
        product.Lodestone__Supplier__c = account.Id;
        insert product; 
		
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
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id, product.Id,pbe.Id, false);
        orderItem.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 0;
        orderItem.IMagic__PO_Quantity__c = 0;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        insert orderItem;
        
        //Creating Inventory
        IMagic__Inventory__c Inventory = D_TestDataFactory.createInventory('Non Serial Inventory',mainStockingLocation.Id,product.Id,false);
        Inventory.IMagic__Quantity_on_Hand__c = 5;
        Inventory.IMagic__Quantity_Reserved__c = 0;
        insert Inventory; 
    }


    @isTest
    static void testgetActiveRecordTypes() {
        Test.startTest();
        List<String> wrap = OrderProductReservedLWC.getActiveRecordTypes('Product2');
        Test.stopTest();   
        Assert.isNotNull(wrap,'wrap should not be null');
    }

    @isTest
    static void testgetProducts() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
        List<OrderProductReservedLWC.OrderLineWrapper> wrap = OrderProductReservedLWC.getProducts(ord.Id);
        Test.stopTest();   
        Assert.isNotNull(wrap,'wrap should not be null');
    }

    @isTest
    static void testreservedOrderProduct() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        List<OrderProductReservedLWC.OrderLineWrapper> wrap = OrderProductReservedLWC.getProducts(ord.Id);
        for(OrderProductReservedLWC.OrderLineWrapper item : wrap){
            item.selectedType = 'Dropship PO';
            item.createPO = true;
        }
        String jsnString = JSON.serialize(wrap);
        Test.startTest();
        String record = OrderProductReservedLWC.reservedOrderProduct(jsnString);
        Test.stopTest();   
        Assert.isNotNull(record,'record should not be null');
    }
}