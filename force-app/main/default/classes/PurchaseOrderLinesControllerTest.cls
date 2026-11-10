@IsTest
public class PurchaseOrderLinesControllerTest {
    @TestSetup
    static void makeData(){
        //Creating Account
        Account account = D_TestDataFactory.createAccount('Test Account Family', true);
		
		//Creating Account
        Account Venaccount = D_TestDataFactory.createVendorAccount('Test Account Family', true);
		

        //Creating Contact
        Contact contact = D_TestDataFactory.CreateContact('Test Contact OAC', account.Id, true);

        //Creating Product
        Product2 product = D_TestDataFactory.createProduct('Test Product', false);
        product.RecordTypeId =  Schema.SObjectType.Product2.getRecordTypeInfosByName().get('Serial Control').getRecordTypeId();
        insert product; 
        Product2 newProduct = D_TestDataFactory.createProduct('Test Product', false); //Inventory don't exist
        newProduct.RecordTypeId =  Schema.SObjectType.Product2.getRecordTypeInfosByName().get('Non Serial Control').getRecordTypeId();
        insert newProduct; 

        //Creating Standard PBE for Product
        PricebookEntry pbe = D_TestDataFactory.createPriceBookEntry(Test.getStandardPricebookId(),product.Id,false );
                  //   pbe.UseStandardPrice=false;
        INSERT pbe;
        PricebookEntry pbe2 = D_TestDataFactory.createPriceBookEntry(Test.getStandardPricebookId(),newProduct.Id,true);

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
        order.Pricebook2Id =Test.getStandardPricebookId();
        insert order;


        //Creating OrderItem
        List<OrderItem> oiList = new List<OrderItem>();
        OrderItem orderItem = D_TestDataFactory.createOrderProduct(order.Id,pbe.Id,product.Id, false);
        orderItem.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        orderItem.Quantity = 10; 
        orderItem.IMagic__Reserved_Quantity__c = 0;
        orderItem.IMagic__PO_Quantity__c = 9;
        orderItem.IMagic__Shipped_Quantity__c = 0;
        orderItem.PricebookEntryId = pbe.Id;
        
        OrderItem orderItem2 = D_TestDataFactory.createOrderProduct(order.Id,pbe2.Id,newProduct.Id, false);
        orderItem2.IMagic__Stocking_Location__c = mainStockingLocation.Id;
        orderItem2.Quantity = 10; 
        orderItem2.IMagic__Reserved_Quantity__c = 0;
        orderItem2.IMagic__PO_Quantity__c = 5;
        orderItem2.IMagic__Shipped_Quantity__c = 0;
        orderItem2.PricebookEntryId = pbe.Id;
        
        oiList.add(orderItem);
        oiList.add(orderItem2); 
		
		//Creating Inventory
        IMagic__Inventory__c Inventory = D_TestDataFactory.createInventory('Detail Inventory',mainStockingLocation.Id,product.Id,false);
        Inventory.IMagic__Quantity_on_Hand__c = 1;
        Inventory.IMagic__Quantity_Reserved__c = 0;
        insert Inventory;

        //Creating Inventory
        IMagic__Inventory__c newInventory = D_TestDataFactory.createInventory('non Detail Inventory',mainStockingLocation.Id,newProduct.Id,false);
        newInventory.IMagic__Quantity_on_Hand__c = 5;
        newInventory.IMagic__Quantity_Reserved__c = 0;
        insert newInventory;

        //Creating Purchase Order
        Lodestone__Purchase_Order__c PO = D_TestDataFactory.createPurchaseOrder(Venaccount.Id,order.Id,'Dropship PO',true);
        
		//Creating Purchase Order Line
        Lodestone__Purchase_Order_Line__c PO_Line = D_TestDataFactory.createPurchaseOrderLine(PO.Id,orderItem.Id,product.Id,mainStockingLocation.Id,Inventory.Id,9,true);
        Lodestone__Purchase_Order_Line__c PO_Line2 = D_TestDataFactory.createPurchaseOrderLine(PO.Id,orderItem2.Id,newProduct.Id,mainStockingLocation.Id,newInventory.Id,5,true);

         
        //Creating Inventory Detail
        IMagic__Inventory_Detail__c createInventoryDetail = D_TestDataFactory.createInventoryDetail(Inventory.Id,null,true);  
	}

    @isTest
    static void testgetPurchaseOrderLines() {
        Lodestone__Purchase_Order__c po = [SELECT Id FROM Lodestone__Purchase_Order__c LIMIT 1];
        Test.startTest();
        List<PurchaseOrderLinesController.purchaseOrderLineWrapper> wrap = PurchaseOrderLinesController.getPurchaseOrderLines(po.Id);
        Test.stopTest();   
        Assert.isNotNull(wrap,'wrap should not be null');
    }

    @isTest
    static void testupdatePurchaseOrderLines() {
        PurchaseOrderLinesController.purchaseOrderLineWrapper powrapper = new PurchaseOrderLinesController.purchaseOrderLineWrapper();
        Order o =[SELECT id FROM Order LIMIT 1];
        
        Map<Id,Id> invId_PoLineId = new Map<Id,Id>();
        Shipment__C shp = D_TestDataFactory.createShipment('DHL', o.id, true);
        Lodestone__Purchase_Order__c po = [SELECT Id ,Name,Lodestone__Account__c ,Lodestone__Order__c FROM Lodestone__Purchase_Order__c LIMIT 1];
        
       // Test.startTest();
        PurchaseOrderLinesController.getPurchaseOrder(po.Id);
        
        PurchaseOrderLinesController.createShipment(po);
        
        PurchaseOrderLinesController.createShipmentLine(new list<PurchaseOrderLinesController.purchaseOrderLineWrapper>{powrapper},shp);
       // Test.stoptest();
        List<PurchaseOrderLinesController.serialNumberWrapper> serialNumberList = new List<PurchaseOrderLinesController.serialNumberWrapper>();
        List<Lodestone__Purchase_Order_Line__c> poLine = [SELECT Id,Inventory__c FROM Lodestone__Purchase_Order_Line__c];
        for(Lodestone__Purchase_Order_Line__c item : poLine){
            invId_PoLineId.put(item.Inventory__c,item.Id);
        }
        List<IMagic__Inventory__c> inventory = [SELECT Id,(SELECT Id,IMagic__Serial_Number__c,IMagic__Inventory__c FROM Inventory_Details__r) FROM IMagic__Inventory__c WHERE Name = 'Detail Inventory'];

        for(Integer i = 0;i < 9;i++){
        PurchaseOrderLinesController.serialNumberWrapper numberWrap = new PurchaseOrderLinesController.serialNumberWrapper();
        numberWrap.purchaseOrderLineId = invId_PoLineId.get(inventory[0].Id);
        numberWrap.serialNumber = String.valueOf(Math.random());
        serialNumberList.add(numberWrap);
        }

        List<PurchaseOrderLinesController.purchaseOrderLineWrapper> wrap = PurchaseOrderLinesController.getPurchaseOrderLines(po.Id);
        for(PurchaseOrderLinesController.purchaseOrderLineWrapper item : wrap){
            item.newQuantity = 5;
            item.serialNumberList = serialNumberList;
        }
        String jsnString = JSON.serialize(wrap);
        Test.startTest();
        PurchaseOrderLinesController.updatePurchaseOrderLines(jsnString,po.Id);
        Test.stopTest();
        Assert.isNotNull(jsnString);
	}
}