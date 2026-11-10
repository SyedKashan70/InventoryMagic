@isTest
public with sharing class LwcLookupControllerTest {
    @TestSetup
    static void makeData(){
        // Test data setup
        List<Product2> productList = new List<Product2>();
        Product2 p1 = D_TestDataFactory.createProduct('ELS testing product 1', true);
        Product2 p2 = D_TestDataFactory.createProduct('ELS testing product 2', true); 
        Product2 p3 = D_TestDataFactory.createProduct('ELS testing product 3', true); 
        Product2 p4 = D_TestDataFactory.createProduct('DSO testing product 1', true); 

         

    }
    static testMethod void testfindRecordsWithFilters() {
        List<Product2> listProduct = [SELECT Id from Product2];
       Test.startTest();
       List<sobject> result = LwcLookupController.findRecordsWithFilters('ELS',
                                                    'Product2',
                                                    ' RecordType.name',
                                                    '',
                                                    'Name ASC',
                                                    100,
                                                    true,
                                                    'Name');
       Test.stopTest();
        
       
     
       //Check if the result is not null
       Assert.isTrue(result.size() > 0);
    }
    
}