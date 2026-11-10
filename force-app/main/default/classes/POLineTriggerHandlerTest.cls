@isTest
public class POLineTriggerHandlerTest {
    
    public static testMethod void UnitTest(){
        
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
         IMagic__Stocking_Location__c StockingLocation = D_TestDataFactory.createStockingLocation('Stocking Location',Warehouse.Id,false);
        StockingLocation.IMagic__is_Main_Stocking_Location__c = false;
        INSERT StockingLocation;
        
        IMagic__Stocking_Location__c StockingLocation2 = D_TestDataFactory.createStockingLocation('Stocking Location',Warehouse.Id,false);
        StockingLocation2.IMagic__is_Main_Stocking_Location__c = true;
        INSERT StockingLocation2;
      
        //Creating Order
        Order order = D_TestDataFactory.createOrder(account.Id, contact.Id, false);
        order.IMagic__Stocking_Location__c = StockingLocation.Id;
        order.IMagic__Warehouse__c = Warehouse.Id;
        order.Status = 'Open';
        insert order;   

        //Creating OrderItem
        List<OrderItem> oiList = new List<OrderItem>();
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem.IMagic__Stocking_Location__c = StockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 0;
        orderItem.IMagic__PO_Quantity__c	 = 0;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        oiList.add(orderItem);
        
        OrderItem orderItem2 = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem2.IMagic__Stocking_Location__c = StockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 0;
        orderItem.IMagic__PO_Quantity__c	 = 0;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        oiList.add(orderItem2);
        insert oiList;
		
        //Creating Inventroy
        IMagic__Inventory__c inv = new IMagic__Inventory__c();
        inv.IMagic__Product__c = product.id;
        inv.IMagic__Cost__c = 100;
        inv.IMagic__Quantity_on_Hand__c = 3;
        inv.IMagic__Quantity_Reserved__c = 3;
        INSERT inv;
    
        //Creating Purchase Order
        Lodestone__Purchase_Order__c po = D_TestDataFactory.createPurchaseOrder(account.id,order.id,'Stock PO',True);
        
		//Creating Purchase Order Line
        Lodestone__Purchase_Order_Line__c poLine = D_TestDataFactory.createPurchaseOrderLine(po.id,orderItem.id,product.Id,StockingLocation2.Id,inv.Id,3.0,true);
       
        POLineTriggerHandler.handlePOLine_Insert_Update(new Set<Id>{poLine.Id});
    }
}