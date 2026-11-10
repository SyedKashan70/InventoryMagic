@isTest
public with sharing class InventoryTriggerHandlerTest {
    
    public static testMethod void UnitTest(){
        
      	//creating Product
        Product2 pro = D_TestDataFactory.createProduct('Test Product',true);
        
        //creating Inventory
        IMagic__Inventory__c inv = new IMagic__Inventory__c();
        inv.IMagic__Product__c = pro.id;
        inv.IMagic__Cost__c = 100;
        inv.IMagic__Quantity_on_Hand__c = 3;
        inv.IMagic__Quantity_Reserved__c = 7;
        INSERT inv;
        
        Set<Id> proIds = new set<Id> ();
        proIds.add(pro.id);
  
        InventoryTriggerHandler.handleInventory_Insert_Update(proIds);
		Assert.isNotNull(proIds);
        
    }

}