@isTest
public class InventoryTriggerTest {
    public static testmethod void UnitTest(){
        
        ////creating Product
		Product2 pro = D_TestDataFactory.createProduct('Test Product',true);
		////creating Inventory
		list<IMagic__Inventory__c> invlist= new list<IMagic__Inventory__c>(); 
        
        IMagic__Inventory__c inv = new IMagic__Inventory__c();
        inv.IMagic__Product__c = pro.id;
        inv.IMagic__Cost__c = 100;
        inv.IMagic__Quantity_on_Hand__c = 3;
        inv.IMagic__Quantity_Reserved__c = 3;
        insert inv;
        
    }
    
}