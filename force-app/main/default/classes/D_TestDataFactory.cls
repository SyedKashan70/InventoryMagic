/**
 * @description       : Methods for creating Data records in Test Classes.
 * @author            : Ameer Hamza
 * @group             : 
 * @last modified on  : 08-24-2024
 * @last modified by  : Syed Kashan
 * Modifications Log
 * Ver   Date         Author        Modification
 * 1.0   03-07-2023   Ameer Hamza   Initial Version
**/
@isTest
public with sharing class D_TestDataFactory {

    public static Account createAccount(string accountName, Boolean doInsert){
        Account account = new Account();
        account.Name = accountName;
        if(doInsert){
            insert account;
        }
        return account;
    }

    public static Contact createContact(String name, Id accId, Boolean doInsert){
        Contact contact = new Contact();
            contact.FirstName = name;
            contact.LastName = 'Contact';
            contact.Email = 'testing1@test.com';
            contact.Phone = '999-999-9999';
            contact.MailingStreet = '123 Test Avenue';
            contact.MailingCity = 'Test';
            contact.MailingState = 'Florida';
            contact.MailingPostalCode = '30010';
            contact.MailingCountry = 'United States';
            contact.AccountId =  accId;
            if(doInsert){
                insert contact;
            } 
        return contact;
    }

    public static IMagic__Stocking_Location__c createMainStockingLocation(String name,Id wareHouseId,Boolean doInsert){
        IMagic__Stocking_Location__c stockingLocation = new IMagic__Stocking_Location__c();
        stockingLocation.Name = name;
        stockingLocation.IMagic__Warehouse__c = wareHouseId;
        stockingLocation.IMagic__is_Main_Stocking_Location__c=true;
        if(doInsert){
            insert stockingLocation;
        }
        return stockingLocation;
    }

    public static Account createVendorAccount(string accountName, Boolean doInsert){
        Account account = new Account();
        account.Name = accountName;
        String VendorrecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Vendor').getRecordTypeId();
        account.RecordTypeId = VendorrecTypeId;
        
        if(doInsert){
            insert account;
        }
        return account;
    }

    
    public static Lodestone__Purchase_Order__c createPurchaseOrder(Id supplierId,Id orderId,String recordtypeName,Boolean doInsert){
        Lodestone__Purchase_Order__c PO = new Lodestone__Purchase_Order__c();
        PO.Lodestone__Account__c = supplierId;
        PO.Lodestone__Order__c = orderId;
        PO.RecordTypeId =  Schema.SObjectType.Lodestone__Purchase_Order__c.getRecordTypeInfosByName().get(recordtypeName).getRecordTypeId();
        if(doInsert){
            insert PO;
        }
        return PO;
    }

    public static Lodestone__Purchase_Order_Line__c createPurchaseOrderLine(Id PO_Id,Id orderProductId,Id productId,Id locationId,Id invId,Decimal orderedQty,Boolean doInsert){
        Lodestone__Purchase_Order_Line__c PO_line = new Lodestone__Purchase_Order_Line__c();
        PO_line.Lodestone__Product__c = productId;
        PO_line.Lodestone__Purchase_Order__c = PO_Id;
        PO_line.Lodestone__Order_Product__c = orderProductId;
        PO_line.Lodestone_Stocking_Location__c = locationId;
        PO_line.IMagic__Inventory__c = invId;
        PO_line.Lodestone__Quantity__c = orderedQty;
        PO_line.IMagic__Received_Quantity__c = 0;
        if(doInsert){
            insert PO_line;
        }
        return PO_line;
    }

    public static Order createOrder(String accountId, String contactId , Boolean doInsert){
        Order order = new Order();
        order.Name = 'Test Order';
        order.Status = 'Open';
        order.EffectiveDate = Date.today();
        order.EndDate = Date.today().addDays(10);  
        order.AccountId = accountId;
        order.BillToContactId =  contactId;
 	     order.Pricebook2Id = Test.getStandardPricebookId();

        if(doInsert){
            insert order;
        }
        return order;
    }

    public static OrderItem createOrderProduct(String orderId,String proId,String pbeId, Boolean doInsert){
        OrderItem orderItem = new OrderItem();
        orderItem.OrderId = orderId;
        orderItem.Quantity = 30;
        orderItem.EndDate = Date.today().addDays(10);
        orderItem.ServiceDate = Date.today(); 
        orderItem.IMagic__Reserved_Quantity__c = 20;
        orderItem.IMagic__Shipped_Quantity__c = 10;
 	    orderItem.PricebookEntryId= pbeId;
        orderItem.UnitPrice = 20;
        orderItem.Product2Id = proId;

        if(doInsert){
            insert orderItem;
        }
        return orderItem;
    }

    public static Product2 createProduct(string ProductName, Boolean doInsert){
        Product2 product = new Product2();
                product.Name = ProductName;
                product.IsActive = true;
        product.Lodestone__Cost_Price__c = 20;
        product.Lodestone__Sale_Price__c = 25;
        product.IMagic__Profit_Margin__c = 10;
        if(doInsert){
            insert product;
        }
        return product;
    }

    public static IMagic__Shipment__c createShipment(string method,Id orderId,Boolean doInsert){
        IMagic__Shipment__c shipment = new IMagic__Shipment__c();
        shipment.IMagic__Shipment_Method__c = method;
        shipment.IMagic__Sales_Order__c = orderId;
        if(doInsert){
            insert shipment;
        }
        return shipment;
    }

    public static IMagic__Shipment_Line__c createShipmentLine(Id productId,Id shipmentId,Boolean doInsert){
        IMagic__Shipment_Line__c shipmentLine = new IMagic__Shipment_Line__c();
        shipmentLine.Product__c = productId;
        shipmentLine.IMagic__Quantity__c = 10;
        shipmentLine.IMagic__Shipments__c = shipmentId;
        if(doInsert){
            insert shipmentLine;
        }
        return shipmentLine;
    }

    public static PricebookEntry createPriceBookEntry(String priceBookId, string productId ,Boolean doInsert){
        PriceBookEntry pre = new PriceBookEntry(
            IsActive = true,
            PriceBook2Id = priceBookId, 
            Product2Id = productId, 
            UnitPrice= 500);
            if(doInsert){
                insert pre;
            }
            return pre;
    } 

    public static IMagic__Warehouse__c createWareHouse(String name,Boolean doInsert){
        IMagic__Warehouse__c wareHouse = new IMagic__Warehouse__c();
        wareHouse.Name = name;
        if(doInsert){
            insert wareHouse;
        }
        return wareHouse;
    }

    public static IMagic__Stocking_Location__c createStockingLocation(String name,Id wareHouseId,Boolean doInsert){
        IMagic__Stocking_Location__c stockingLocation = new IMagic__Stocking_Location__c();
        stockingLocation.Name = name;
        stockingLocation.IMagic__Warehouse__c	 = wareHouseId;
        if(doInsert){
            insert stockingLocation;
        }
        return stockingLocation;
    }

    public static IMagic__Inventory__c createInventory(String name,Id stockkingLocationId,Id productId,Boolean doInsert){
        IMagic__Inventory__c inventory = new IMagic__Inventory__c();
        inventory.Name = name;
        inventory.IMagic__Quantity_on_Hand__c = 200;
        inventory.IMagic__Quantity_Reserved__c = 30;
        inventory.IMagic__Stocking_Location__c = stockkingLocationId;
        inventory.IMagic__Product__c = productId;
        if(doInsert){
            insert inventory;
        }
        return inventory;
    }

    public static IMagic__Inventory_Detail__c createInventoryDetail(Id inventoryId,Id orderItemId,Boolean doInsert){
        IMagic__Inventory_Detail__c detail = new IMagic__Inventory_Detail__c();
        detail.Name = String.valueOf(Math.random());
        detail.IMagic__Inventory__c = inventoryId;
        detail.IMagic__Order_Product__c = orderItemId;
        detail.IMagic__Quantity__c = orderItemId != null ? 0 : 1;
        detail.IMagic__Quantity_on_order__c = orderItemId != null ? 1 : 0;
        detail.IMagic__Serial_Number__c = String.valueOf(Math.random());
        if(doInsert){
            insert detail;
        }
        return detail;
    }

    public static IMagic__Stock_Adjustment__c createStockAdjusment(Boolean doInsert){
        IMagic__Stock_Adjustment__c adjustment = new IMagic__Stock_Adjustment__c();
        adjustment.Adjustment_Date__c = Date.today();
        if(doInsert){
            insert adjustment;
        }
        return adjustment;
    }

    public static IMagic__Stock_Adjustment_Line__c createStockAdjusmentLine(Id adjustmentId,String type,Boolean doInsert){
        IMagic__Stock_Adjustment_Line__c adjustmentLine = new IMagic__Stock_Adjustment_Line__c();
        adjustmentLine.IMagic__StockAdjustment__c = adjustmentId;
        adjustmentLine.IMagic__AdjustmentType__c = type;
        adjustmentLine.IMagic__QuantityAdjusted__c = 10;
        if(doInsert){
            insert adjustmentLine;
        }
        return adjustmentLine;
    }
}