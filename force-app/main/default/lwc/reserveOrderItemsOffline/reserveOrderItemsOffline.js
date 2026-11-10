/**
 * @description       : 
 * @author            : Syed Kashan
 * @group             : 
 * @last modified on  : 06-05-2025
 * @last modified by  : Syed Kashan
**/
import { LightningElement,track } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ReserveOrderItemsOffline extends LightningElement {
    @track orderItemTable = [];
    showSerialModal = false;
    
    get isMobile() {
        return FORM_FACTOR === 'Small' ? true : false;
    }

    get groupedOrderItems() {
        const grouped = {};
        this.orderItemTable.forEach(item => {
            if (!grouped[item.orderNumber]) {
                grouped[item.orderNumber] = {
                    items: [],
                    accountName: item.orderAccountName
                };
            }
            grouped[item.orderNumber].items.push(item);
        });
    
        return Object.keys(grouped).map(orderNumber => ({
            orderNumber,
            accountName: grouped[orderNumber].accountName,
            items: grouped[orderNumber].items,
            label: `${orderNumber} - ${grouped[orderNumber].accountName}`
        }));
    }
    
    

    getNewObject() {
        return {
          Id: '',
          orderId: '',
          orderNumber: '',
          stockingLocationId: '',
          stockingLocationName: '',
          unitPrice: 0,
          quantityOrdered: 0,
          quantityReserved: 0,
          quantityRemaining: 0,
          newQuantity: 0,
          productId: '',
          productName: '',
          productRecordTypeName: '',
          isSerialControlProduct: false,
          supplierId: '',
          supplierName: '',
          orderAccountId: '',
          orderAccountName: '',
          inventoryId: '',
          inventoryAvailableQuantity: 0,
          serialList: [],
          isSelected: false,
          get showSerialBtn(){
            return (this.isSerialControlProduct && this.newQuantity > 0 && this.inventoryAvailableQuantity > 0 && (this.newQuantity <= this.quantityRemaining));
          },
          get minimumReservedQty(){
            return this.isSelected ? 1 : 0;
          },
          get disableInput(){
            return this.isSelected ? false : true;
          }
        };
    }

    connectedCallback() {
        this.fetchOrderItems();
    }

    fetchOrderItems() {
        try {
            const cached = localStorage.getItem('cachedorderItemToReserve') || '[]';
            const cachedInventoryRaw = localStorage.getItem('cachedInventory') || '[]';
    
            const data = JSON.parse(cached);
            const inventoryData = JSON.parse(cachedInventoryRaw);
    
            // Create a Map for quick inventory lookup
            const inventoryMap = new Map();
            inventoryData.forEach(inv => {
                inventoryMap.set(inv.Id, inv);
            });
    
            if (Array.isArray(data)) {
                this.orderItemTable = []; // Clear existing table
                data.forEach(element => {
                    let tempObj = this.getNewObject();
    
                    tempObj.Id = element.Id;
                    tempObj.orderId = element.orderId;
                    tempObj.orderNumber = element.orderNumber;
                    tempObj.stockingLocationId = element.stockingLocationId;
                    tempObj.stockingLocationName = element.stockingLocationName;
                    tempObj.unitPrice = element.unitPrice;
                    tempObj.quantityOrdered = element.quantityOrdered;
                    tempObj.quantityReserved = element.quantityReserved;
                    tempObj.quantityRemaining = element.quantityRemaining;
                    tempObj.newQuantity = element.newQuantity;
                    tempObj.productId = element.productId;
                    tempObj.productName = element.productName;
                    tempObj.productRecordTypeName = element.productRecordTypeName;
                    tempObj.isSerialControlProduct = element.isSerialControlProduct;
                    tempObj.supplierId = element.supplierId;
                    tempObj.supplierName = element.supplierName;
                    tempObj.orderAccountId = element.orderAccountId;
                    tempObj.orderAccountName = element.orderAccountName;
                    tempObj.inventoryId = element.inventoryId;
                    tempObj.serialList = element.serialList;
    
                    // Lookup inventoryAvailableQuantity from inventory map
                    const invRecord = inventoryMap.get(tempObj.inventoryId);
                    if (invRecord) {
                        tempObj.inventoryAvailableQuantity = invRecord.quantityOnHand 
                    } else {
                        tempObj.inventoryAvailableQuantity = 0;
                        console.warn(`Inventory record not found for Id: ${tempObj.inventoryId}`);
                    }
    
                    this.orderItemTable.push(tempObj);
                });
            } else {
                console.warn('Cached data is not in expected array format.');
            }
        } catch (error) {
            console.error('Error reading cache:', error);
        }
    }
    
    
    handleCancel() {
        const event = new CustomEvent('cancel');
        this.dispatchEvent(event);
    }   

    handleCheckboxChange(event) {
        const itemId = event.target.dataset.id;
        const index = this.orderItemTable.findIndex((element) => element.Id == itemId);
        this.orderItemTable[index].isSelected = event.target.checked;
    }

    handleQtyChange(event) {
        const itemId = event.target.dataset.id;
        const value = parseInt(event.detail.value, 10);
        const index = this.orderItemTable.findIndex((element) => element.Id == itemId);
    
        if (index !== -1) {
            const item = this.orderItemTable[index];
            item.newQuantity = value;
            item.serialList = [];
        }
    }
    

    handleAddSerialClick(event){
        let itemId = event.target.dataset.id; 
        const index = this.orderItemTable.findIndex((element) => element.Id == itemId);
        let numOfSerials = 0;
        if(this.orderItemTable[index].quantityRemaining >= this.orderItemTable[index].newQuantity){
          numOfSerials = this.orderItemTable[index].newQuantity;
        }
        else{
          numOfSerials = this.orderItemTable[index].quantityRemaining;
        }
        let tempSerialRec = {
            numOfSerials: numOfSerials,
            serialList: this.orderItemTable[index].serialList,
            invId: this.orderItemTable[index].inventoryId,
            // queryFilters: ` AND  Quantity__c > 0 AND Picked__c = TRUE `
        }
        this.serialRecord = tempSerialRec;
        this.showSerialModal = true;
    }

    handleCloseModal(){
        this.showSerialModal = false;
    }

    handleSaveSerials(event){
        const invId = event.detail.invId;
        const index = this.orderItemTable.findIndex((element) => element.inventoryId == invId);
        this.orderItemTable[index].serialList = event.detail.serialList;
        this.showSerialModal = false;
    }


    validateData() {
        // Ensure at least one product is added
        if (this.orderItemTable.length == 0) {
            this.showToast('Error', 'At least add one product', 'error');
            return false;
        }
    
    
        // Check if all inputs are valid (you can define the `isInputValid()` method)
        if (!this.isInputValid()) {
            return false;  // Assuming isInputValid() checks for additional conditions
        }
    
        // Filter selected products
        const selectedorderItemTable = this.orderItemTable.filter(element => element.isSelected);
    
        // Ensure at least one product is selected
        if (selectedorderItemTable.length === 0) {
            this.showToast('Error', 'Please select at least one product to process.', 'error');
            return false;
        }
    
    
        // Check for serial-controlled products with missing serial numbers
        const invalidRow = this.orderItemTable.find(element => {
            if (element.isSelected && element.isSerialControlProduct && element.newQuantity > 0) {
                // Check if the serial list is empty or has any null/undefined serial Ids
                return element.serialList.length === 0 || 
                       element.serialList.some(serial => !serial.Id);
            }
            return false;  // Skip rows that aren't selected or aren't serial controlled
        });
    
        // Show error if any product has missing serials
        if (invalidRow) {
            this.showToast('Error', `${invalidRow.productName} has missing serials`, 'error');
            return false;
        }
    
        // If all checks pass, return true
        return true;
    }
    
    handleCreateOrder() {
        const isValid = this.validateData();
        if (!isValid) {
            return;  
        }
        this.loadToLocalStorage();
    }
    

    // loadToLocalStorage(){
    //    // Step 1: Get selected products (already selected from UI)
    //     const selectedProducts = this.orderItemTable.filter(product => product.isSelected);
      
    //     // Step 2: Load cached order items and inventory
    //     let cachedOrderItems = JSON.parse(localStorage.getItem('cachedorderItemToReserve')) || [];
    //     let cachedInventory = JSON.parse(localStorage.getItem('cachedInventory')) || [];

    //     // Step 3: Loop through each selected product
    //     selectedProducts.forEach(selected => {
    //         // Update cachedOrderItems
    //         const orderItem = cachedOrderItems.find(item => item.Id === selected.Id);
    //         if (orderItem) {
    //             orderItem.quantityReserved = Number(orderItem.quantityReserved) + Number(selected.newQuantity);
    //             let newRemainingQty = Number(orderItem.quantityOrdered) - Number(orderItem.quantityReserved);
    //             orderItem.quantityRemaining = newRemainingQty
    //         }

    //         // Update inventory
    //         const inventory = cachedInventory.find(inv => inv.Id === selected.inventoryId);
    //         if (inventory) {
    //             inventory.quantityOnHand -= selected.newQuantity;
    //             inventory.quantityReserved += selected.newQuantity;
    //         }

    //         // Optional: Handle serial-controlled products
    //         console.log('selected.isSerialControlProduct :: '+selected.isSerialControlProduct);
    //         console.log('selected.serialList :: '+JSON.stringify(selected.serialList));
    //         if (selected.isSerialControlProduct) {
    //             selected.serialList.forEach(serial => {
    //                 const invSerial = cachedInventory.find(inv => inv.Id === serial.Id);
    //                 if (invSerial) {
    //                     invSerial.isOrdered = true;
    //                 }
    //             });
    //         }
    //     });
    //     localStorage.setItem('cachedInventory', JSON.stringify([]));
    //     localStorage.removeItem('cachedInventory');
    //     console.log('JSON.stringify(cachedOrderItems) :: '+JSON.stringify(cachedOrderItems));
    //     // Step 4: Save updated data back to localStorage
    //     localStorage.setItem('cachedorderItemToReserve', JSON.stringify(cachedOrderItems));
    //     localStorage.setItem('cachedInventory', JSON.stringify(cachedInventory));




       

    //     this.dispatchEvent(new CustomEvent('cancel'));
    // }

    loadToLocalStorage() {
        // Step 1: Get selected products (already selected from UI)
        const selectedProducts = this.orderItemTable.filter(product => product.isSelected);
    
        // Step 2: Load cached order items and inventory
        let cachedOrderItems = JSON.parse(localStorage.getItem('cachedorderItemToReserve')) || [];
        let cachedInventory = JSON.parse(localStorage.getItem('cachedInventory')) || [];
    
        // Step 3: Loop through each selected product
        selectedProducts.forEach(selected => {
            // Update cachedOrderItems
            const orderItem = cachedOrderItems.find(item => item.Id === selected.Id);
            if (orderItem) {
                orderItem.quantityReserved = Number(orderItem.quantityReserved) + Number(selected.newQuantity);
                let newRemainingQty = Number(orderItem.quantityOrdered) - Number(orderItem.quantityReserved);
                orderItem.quantityRemaining = newRemainingQty;
    
                // Maintain serialList if serial-controlled
                if (selected.isSerialControlProduct) {
                    const existingSerials = orderItem.serialList || [];
                    const newSerials = selected.serialList || [];
                    // Merge and deduplicate based on serial Id
                    const mergedSerials = [...existingSerials, ...newSerials].filter(
                        (serial, index, self) =>
                            index === self.findIndex(s => s.Id === serial.Id)
                    );
                    orderItem.serialList = mergedSerials;
                }
            }
    
            // Update inventory
            const inventory = cachedInventory.find(inv => inv.Id === selected.inventoryId);
            if (inventory) {
                inventory.quantityOnHand -= selected.newQuantity;
                inventory.quantityReserved += selected.newQuantity;
            }
    
            // Optional: Handle serial-controlled products in inventory
            if (selected.isSerialControlProduct) {
                selected.serialList.forEach(serial => {
                    const invSerial = cachedInventory.find(inv => inv.Id === serial.Id);
                    if (invSerial) {
                        invSerial.isOrdered = true;
                    }
                });
            }
        });
    
        // Log for debugging
        console.log('JSON.stringify(cachedOrderItems) :: ' + JSON.stringify(cachedOrderItems));
        console.log('JSON.stringify(cachedInventory) :: ' + JSON.stringify(cachedInventory));
    
        // Step 4: Save updated data back to localStorage
        localStorage.setItem('cachedorderItemToReserve', JSON.stringify(cachedOrderItems));
        localStorage.setItem('cachedInventory', JSON.stringify(cachedInventory));
    
        // Step 5: Dispatch event to close modal or perform next action
        this.dispatchEvent(new CustomEvent('cancel'));
    }
    


    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }
    
    isInputValid(){
        let isValid = true;
        let inputFields = this.template.querySelectorAll('.validate');
        inputFields.forEach(inputField => {
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValid = false;
            } 
        });
        return isValid;
    }
    
}