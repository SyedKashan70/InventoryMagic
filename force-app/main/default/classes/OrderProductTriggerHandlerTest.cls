@isTest
public with sharing class OrderProductTriggerHandlerTest {
    @TestSetup
    static void makeData(){
        //Creating Account
        Account account = D_TestDataFactory.createAccount('Test Account Family', true);

        //Creating Contact
        Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);

        //Creating Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false); //Inventory don't exist
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
        Order order = D_TestDataFactory.createOrder(account.Id, contact.Id, false);
        order.IMagic__Stocking_Location__c = StockingLocation.Id;
        order.IMagic__Warehouse__c = Warehouse.Id;
        order.Status = 'Open';
        insert order;   


        //Creating OrderItem
        List<OrderItem> oiList = new List<OrderItem>();
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 0;
        orderItem.IMagic__PO_Quantity__c = 0;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        oiList.add(orderItem);
        
        OrderItem orderItem2 = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem2.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 0;
        orderItem.IMagic__PO_Quantity__c = 0;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        oiList.add(orderItem2);
        insert oiList;
    }

    @isTest
    static void testupdateOrderProducts() {
        List<OrderItem> oiList = [SELECT Id,OrderId FROM OrderItem];
        Test.startTest();
        OrderProductTriggerHandler.updateOrderProducts(oiList);
        Test.stopTest();   
        Assert.isNotNull(oiList,'oiList should not be null');
    }
}