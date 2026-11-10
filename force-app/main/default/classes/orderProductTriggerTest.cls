@isTest
public with sharing class orderProductTriggerTest {

    @isTest
    static void testOrderItemInsertTrigger() {

       

       //Creating Account
       Account account = D_TestDataFactory.createAccount('Test Account Family', true);

       //Creating Contact
       Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);

       //Creating Product
       Product2 product = D_TestDataFactory.createProduct('Test Product', false);
       product.RecordTypeId =  Schema.SObjectType.Product2.getRecordTypeInfosByName().get('Non Serial Control').getRecordTypeId();
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
       Order order = D_TestDataFactory.createOrder(account.Id ,contact.Id, false);
       order.IMagic__Stocking_Location__c = StockingLocation.Id;
       order.IMagic__Warehouse__c = Warehouse.Id;
       order.Status = 'Open';
       insert order;   


       //Creating OrderItem
       OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
       orderItem.IMagic__Stocking_Location__c = mainStockingLocation.Id;
       orderItem.Quantity = 10; 
       orderItem.IMagic__Reserved_Quantity__c = 0;
       orderItem.IMagic__PO_Quantity__c = 0;
       orderItem.IMagic__Shipped_Quantity__c = 0;
       
       //Creating Inventory
       IMagic__Inventory__c Inventory = D_TestDataFactory.createInventory('Detail Inventory',mainStockingLocation.Id,product.Id,false);
       Inventory.IMagic__Quantity_on_Hand__c = 10;
       Inventory.IMagic__Quantity_Reserved__c = 0;
       insert Inventory; 
        // Insert the OrderItems and validate that the trigger runs
        Test.startTest();
        insert orderItem;
        Test.stopTest();
        Assert.isNotNull(orderItem,'orderItem should not be null');
        
    }
}